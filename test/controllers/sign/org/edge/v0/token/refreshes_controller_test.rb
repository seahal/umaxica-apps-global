# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Edge::V0::Token::RefreshesControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_tokens, :operator_occurrence_statuses

  setup do
    @staff = operators(:one)
    @host = ENV.fetch("ID_STAFF_URL", "test.umaxica.com")
    @original_allow_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @original_allow_forgery_protection
  end

  test "POST refresh with valid refresh token sets both access and refresh cookies" do
    token_record = OperatorToken.create!(staff: @staff)
    refresh_plain = token_record.rotate_refresh_token!

    csrf_token = "test_csrf_token"
    cookies["csrf_token"] = csrf_token
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: {
           "Host" => @host,
           "Accept" => "application/json",
           "X-CSRF-Token" => csrf_token,
         },
         as: :json

    assert_response :ok

    assert response_has_cookie?(AuthenticationBase::ACCESS_COOKIE_KEY),
           "Response should set access cookie (#{AuthenticationBase::ACCESS_COOKIE_KEY})"
    assert response_has_cookie?(AuthenticationBase::REFRESH_COOKIE_KEY),
           "Response should set refresh cookie (#{AuthenticationBase::REFRESH_COOKIE_KEY})"

    raw_header = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    cookie_lines = raw_header.is_a?(Array) ? raw_header : raw_header.to_s.split("\n")
    access_cookie = cookie_lines.find { |line| line.start_with?("#{AuthenticationBase::ACCESS_COOKIE_KEY}=") }.to_s
    refresh_cookie = cookie_lines.find { |line| line.start_with?("#{AuthenticationBase::REFRESH_COOKIE_KEY}=") }.to_s

    assert_match(/samesite=strict/i, access_cookie)
    assert_match(/samesite=strict/i, refresh_cookie)

    json = response.parsed_body

    assert json["refreshed"]
  end

  test "POST refresh syncs preference_consented cookie on success" do
    csrf_token = "test_csrf_token"
    cookies["csrf_token"] = csrf_token
    expires_at = Time.utc(2035, 5, 6, 7, 8, 9)

    travel_to(expires_at - PreferenceBase::REFRESH_TOKEN_TTL) do
      token_record = OperatorToken.create!(staff: @staff)
      refresh_plain = token_record.rotate_refresh_token!
      cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = refresh_plain

      with_cookie_domain_credentials(COOKIE_DOMAIN_ORG: ".umaxica.org") do
        if true # Replaced STUB stub with real execution as per G1
          post "/edge/v0/token/refresh",
               headers: {
                 "Host" => @host,
                 "Accept" => "application/json",
                 "X-CSRF-Token" => csrf_token,
               },
               as: :json
        end
      end
    end

    assert_response :ok
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "preference_consented=0"
    assert_includes set_cookie, "domain=.umaxica.org"
    assert_includes set_cookie.downcase, "path=/"
    expires = response_cookie_expiry("preference_consented")

    assert_not_nil expires
    assert_in_delta expires_at.to_i, expires.to_i, 1
  end

  test "GET check with valid access token from refresh returns 200" do
    token_record = OperatorToken.create!(staff: @staff)
    refresh_plain = token_record.rotate_refresh_token!

    csrf_token = "test_csrf_token"
    cookies["csrf_token"] = csrf_token
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: {
           "Host" => @host,
           "Accept" => "application/json",
           "X-CSRF-Token" => csrf_token,
         },
         as: :json

    assert_response :ok

    response_cookies = extract_cookies_from_response
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = response_cookies[AuthenticationBase::ACCESS_COOKIE_KEY]

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :ok
    json = response.parsed_body

    assert json["authenticated"], "Operator should be authenticated"
  end

  test "POST refresh with old refresh token after rotation returns 401" do
    token_record = OperatorToken.create!(staff: @staff)
    old_refresh_plain = token_record.rotate_refresh_token!
    token_record.rotate_refresh_token!

    csrf_token = "test_csrf_token"
    cookies["csrf_token"] = csrf_token
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = old_refresh_plain

    post "/edge/v0/token/refresh",
         headers: {
           "Host" => @host,
           "Accept" => "application/json",
           "X-CSRF-Token" => csrf_token,
         },
         as: :json

    assert_response :unauthorized
    json = response.parsed_body

    assert_equal "invalid_refresh_token", json["error_code"]
  end

  test "POST refresh with restricted token returns localized error message" do
    token_record = OperatorToken.create!(
      staff: @staff, staff_token_status_id: OperatorTokenStatus::RESTRICTED,
    )
    refresh_plain = token_record.rotate_refresh_token!(discarded_at: 15.minutes.from_now)

    csrf_token = "test_csrf_token"
    cookies["csrf_token"] = csrf_token
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: {
           "Host" => @host,
           "Accept" => "application/json",
           "X-CSRF-Token" => csrf_token,
         },
         as: :json

    assert_response :forbidden

    json = response.parsed_body

    assert_equal I18n.t("sign.token_refresh.errors.restricted_session"), json["error"]
    assert_equal "restricted_session", json["error_code"]
  end

  test "POST refresh with cookie token and missing CSRF is rejected when forgery protection is enabled" do
    token_record = OperatorToken.create!(staff: @staff)
    refresh_plain = token_record.rotate_refresh_token!

    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = refresh_plain

    with_forgery_protection do
      post "/edge/v0/token/refresh",
           headers: {
             "Host" => @host,
             "Accept" => "application/json",
           },
           as: :json
    end

    assert_response :unprocessable_content
    assert_nil token_record.reload.rotated_at
  end

  private

  def with_cookie_domain_credentials(overrides)
    creds = Rails.app.creds
    fetch = ->(key, default: nil) { overrides.fetch(key, default) }

    creds.stub(:option, fetch) do
      yield
    end
  end
end
