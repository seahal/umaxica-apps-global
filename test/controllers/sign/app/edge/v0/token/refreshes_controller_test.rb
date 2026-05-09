# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Edge::V0::Token::RefreshesControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :user_tokens, :user_occurrence_statuses

  setup do
    @user = users(:one)
    @host = ENV.fetch("ID_SERVICE_URL", "test.umaxica.com")
    @csrf_token = nil
    @device_id = SecureRandom.uuid
  end

  test "POST refresh with valid refresh token sets both access and refresh cookies" do
    # Create a token record and generate a refresh token
    token_record = UserToken.create!(user: @user, device_id: @device_id)
    refresh_plain = token_record.rotate_refresh_token!

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true, device_id: @device_id),
         as: :json

    assert_response :ok

    # Verify Set-Cookie headers contain both access and refresh cookies
    assert response_has_cookie?(Authentication::Base::ACCESS_COOKIE_KEY),
           "Response should set access cookie (#{Authentication::Base::ACCESS_COOKIE_KEY})"
    assert response_has_cookie?(Authentication::Base::REFRESH_COOKIE_KEY),
           "Response should set refresh cookie (#{Authentication::Base::REFRESH_COOKIE_KEY})"

    raw_header = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    cookie_lines = raw_header.is_a?(Array) ? raw_header : raw_header.to_s.split("\n")
    access_cookie = cookie_lines.find { |line| line.start_with?("#{Authentication::Base::ACCESS_COOKIE_KEY}=") }.to_s
    refresh_cookie = cookie_lines.find { |line| line.start_with?("#{Authentication::Base::REFRESH_COOKIE_KEY}=") }.to_s

    assert_match(/samesite=lax/i, access_cookie)
    assert_match(/samesite=lax/i, refresh_cookie)

    # Verify JSON response indicates success
    json = response.parsed_body

    assert json["refreshed"]
  end

  test "POST refresh syncs preference_consented cookie on success" do
    expires_at = Time.utc(2034, 4, 5, 6, 7, 8)

    travel_to(expires_at - Preference::Base::REFRESH_TOKEN_TTL) do
      token_record = UserToken.create!(user: @user, device_id: @device_id)
      refresh_plain = token_record.rotate_refresh_token!
      cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

      with_cookie_domain_credentials(COOKIE_DOMAIN_APP: ".app.localhost") do
        if true # Replaced STUB stub with real execution as per G1
          post "/edge/v0/token/refresh",
               headers: json_headers(with_csrf: true, device_id: @device_id),
               as: :json
        end
      end
    end

    assert_response :ok
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "preference_consented=0"
    assert_includes set_cookie, "domain=.app.localhost"
    assert_includes set_cookie.downcase, "path=/"
    expires = response_cookie_expiry("preference_consented")

    assert_not_nil expires
    assert_in_delta expires_at.to_i, expires.to_i, 1
  end

  test "POST refresh syncs preference_consented=0 when consent is false" do
    expires_at = Time.utc(2034, 6, 7, 8, 9, 10)

    travel_to(expires_at - Preference::Base::REFRESH_TOKEN_TTL) do
      token_record = UserToken.create!(user: @user, device_id: @device_id)
      refresh_plain = token_record.rotate_refresh_token!
      cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

      with_cookie_domain_credentials(COOKIE_DOMAIN_APP: ".app.localhost") do
        if true # Replaced STUB stub with real execution as per G1
          post "/edge/v0/token/refresh",
               headers: json_headers(with_csrf: true, device_id: @device_id),
               as: :json
        end
      end
    end

    assert_response :ok
    set_cookie = response.headers["Set-Cookie"].to_s

    assert_includes set_cookie, "preference_consented=0"
    assert_includes set_cookie, "domain=.app.localhost"
    assert_includes set_cookie.downcase, "path=/"
    expires = response_cookie_expiry("preference_consented")

    assert_not_nil expires
    assert_in_delta expires_at.to_i, expires.to_i, 1
  end

  test "GET check with valid access token from refresh returns 200" do
    # Create a token record and generate tokens
    token_record = UserToken.create!(user: @user, device_id: @device_id)
    refresh_plain = token_record.rotate_refresh_token!

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    # First, refresh to get new tokens
    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true, device_id: @device_id),
         as: :json

    assert_response :ok

    # Extract cookies from Set-Cookie response header
    response_cookies = extract_cookies_from_response

    # Set the new access cookie for the next request
    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = response_cookies[Authentication::Base::ACCESS_COOKIE_KEY]

    # Now check should succeed
    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :ok
    json = response.parsed_body

    assert json["authenticated"], "User should be authenticated"
  end

  test "POST refresh with old refresh token after rotation returns 401" do
    # Create a token record and generate a refresh token
    token_record = UserToken.create!(user: @user, device_id: @device_id)
    old_refresh_plain = token_record.rotate_refresh_token!

    # Rotate once via endpoint
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = old_refresh_plain
    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true, device_id: @device_id),
         as: :json

    assert_response :ok

    # Try to use the old refresh token
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = old_refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true, device_id: @device_id),
         as: :json

    assert_response :unauthorized
    json = response.parsed_body

    assert_equal "invalid_refresh_token", json["error_code"]
    assert_equal "refresh_reuse_detected", UserOccurrence.order(:id).last&.event_type
  end

  test "GET check with invalid access token returns 401" do
    # Set an invalid access token
    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = "invalid.jwt.token"

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :unauthorized
    json = response.parsed_body

    assert_not json["authenticated"]
  end

  test "GET check without access token returns 401" do
    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :unauthorized
    json = response.parsed_body

    assert_not json["authenticated"]
  end

  test "POST refresh with missing refresh token returns 400" do
    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true),
         as: :json

    assert_response :bad_request
    json = response.parsed_body

    assert_equal "missing_refresh_token", json["error_code"]
  end

  test "POST refresh with expired refresh token returns 401" do
    # Create a token record with expired refresh
    token_record = UserToken.create!(user: @user, device_id: @device_id)
    refresh_plain = token_record.rotate_refresh_token!
    token_record.update_columns(lapses_at: 1.day.ago)

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true, device_id: @device_id),
         as: :json

    assert_response :unauthorized
  end

  test "POST refresh with revoked token returns 401" do
    # Create a token record and revoke it
    token_record = UserToken.create!(user: @user, device_id: @device_id)
    refresh_plain = token_record.rotate_refresh_token!
    token_record.revoke!

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true, device_id: @device_id),
         as: :json

    assert_response :unauthorized
  end

  test "POST refresh with restricted token returns 403 and does not rotate token" do
    token_record = UserToken.create!(user: @user, status: UserToken::STATUS_RESTRICTED, device_id: @device_id)
    refresh_plain = token_record.rotate_refresh_token!(lapses_at: 15.minutes.from_now)
    before_generation = token_record.refresh_token_generation
    before_digest = token_record.refresh_token_digest

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true, device_id: @device_id),
         as: :json

    assert_response :forbidden
    json = response.parsed_body

    assert_equal "restricted_session", json["error_code"]

    token_record.reload

    assert_equal before_generation, token_record.refresh_token_generation
    assert_equal before_digest, token_record.refresh_token_digest
  end

  test "POST refresh with restricted token returns localized error message" do
    token_record = UserToken.create!(user: @user, status: UserToken::STATUS_RESTRICTED, device_id: @device_id)
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] =
      token_record.rotate_refresh_token!(lapses_at: 15.minutes.from_now)

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true, device_id: @device_id),
         as: :json

    assert_response :forbidden

    json = response.parsed_body

    assert_equal I18n.t("sign.token_refresh.errors.restricted_session"), json["error"]
    assert_equal "restricted_session", json["error_code"]
  end

  test "refresh cookie contains a valid rotated token" do
    token_record = UserToken.create!(user: @user, device_id: @device_id)
    refresh_plain = token_record.rotate_refresh_token!

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true, device_id: @device_id),
         as: :json

    assert_response :ok

    # The cookie value should be a valid refresh token (public_id.verifier format)
    new_value = cookies[Authentication::Base::REFRESH_COOKIE_KEY]

    assert_predicate new_value, :present?, "Refresh cookie should be present after rotation"

    public_id, verifier = UserToken.parse_refresh_token(new_value)

    assert_predicate public_id, :present?, "Rotated refresh token should contain a public_id"
    assert_predicate verifier, :present?, "Rotated refresh token should contain a verifier"
  end

  test "access cookie uses correct TTL" do
    # Create a token record and generate a refresh token
    token_record = UserToken.create!(user: @user, device_id: @device_id)
    refresh_plain = token_record.rotate_refresh_token!

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    freeze_time do
      post "/edge/v0/token/refresh",
           headers: json_headers(with_csrf: true, device_id: @device_id),
           as: :json

      assert_response :ok

      # Check the expires attribute of the access cookie
      expiry = response_cookie_expiry(Authentication::Base::ACCESS_COOKIE_KEY)

      assert_not_nil expiry, "Access cookie should have expires attribute"

      # Should be approximately 1 hour from now (within a few seconds tolerance)
      expected_expiry = Authentication::Base::ACCESS_TOKEN_TTL.from_now

      assert_in_delta expected_expiry.to_i, expiry.to_i, 5,
                      "Access cookie expiry should be ~1 hour from now"
    end
  end

  test "POST refresh without CSRF token succeeds (currently skipped for Edge)" do
    token_record = UserToken.create!(user: @user, device_id: @device_id)
    refresh_plain = token_record.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: false, device_id: @device_id),
         as: :json

    assert_response :ok
    json = response.parsed_body

    assert json["refreshed"]
  end

  test "POST refresh rejects deactivated user even with valid refresh token" do
    @user.update!(
      deactivated_at: Time.current, withdrawal_started_at: 1.hour.ago,
      lapses_at: 30.days.from_now,
      purge_at: 31.days.from_now,
    )

    token_record = UserToken.create!(user: @user, device_id: @device_id)
    refresh_plain = token_record.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true, device_id: @device_id),
         as: :json

    assert_includes [401, 403], response.status
    json = response.parsed_body

    assert_not json["refreshed"]
    assert_predicate json["error_code"], :present?
  end

  test "POST refresh denies when device_id missing and writes occurrence" do
    token_record = UserToken.create!(user: @user, device_id: SecureRandom.uuid)
    refresh_plain = token_record.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true).merge("X-STRICT-DEVICE-CHECK" => "1"),
         as: :json

    assert_response :unauthorized
    occurrence = UserOccurrence.order(:id).last

    assert_equal "refresh_device_missing", occurrence.event_type
    assert_equal 1, occurrence.status_id
    assert_equal "missing", occurrence.context["reason"]
    assert_predicate occurrence.context["request_id"], :present?
    assert_predicate occurrence.context["ip_hash"], :present?
  end

  test "POST refresh denies when header and cookie device_id mismatch" do
    token_record = UserToken.create!(user: @user, device_id: "cookie-device-id")
    refresh_plain = token_record.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true, device_id: "cookie-device-id"),
         as: :json

    assert_response :ok

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true, device_id: "header-device-id"),
         as: :json

    assert_response :unauthorized
    occurrence = UserOccurrence.order(:id).last

    assert_equal "refresh_device_mismatch", occurrence.event_type
    assert_equal "mismatch", occurrence.context["reason"]
    assert_equal "both", occurrence.context["device_source"]
  end

  test "POST refresh denies when device_id mismatches token family device_id" do
    token_record = UserToken.create!(user: @user, device_id: "server-device-id")
    refresh_plain = token_record.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true, device_id: "different-device-id"),
         as: :json

    assert_response :unauthorized
    occurrence = UserOccurrence.order(:id).last

    assert_equal "refresh_device_mismatch", occurrence.event_type
    assert_equal "mismatch", occurrence.context["reason"]
  end

  test "device_id cookie is HttpOnly and contains raw UUID" do
    token_record = UserToken.create!(user: @user, device_id: @device_id)
    refresh_plain = token_record.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true, device_id: @device_id),
         as: :json

    assert_response :ok

    raw_header = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    cookie_lines = raw_header.is_a?(Array) ? raw_header : raw_header.to_s.split("\n")
    device_line = cookie_lines.find { |line| line.start_with?("#{Authentication::Base::DEVICE_COOKIE_KEY}=") }

    assert_not_nil device_line, "Response should set device_id cookie"
    assert_match(/httponly/i, device_line)
    # Cookie now contains plaintext UUID (DB stores the digest for security)
    assert_match(
      /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i,
      CGI.unescape(device_line),
    )
  end

  test "device_id cookie is set on token refresh" do
    token_record = UserToken.create!(user: @user, device_id: @device_id)
    refresh_plain = token_record.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true, device_id: @device_id),
         as: :json

    assert_response :ok

    raw_header = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    cookie_lines = raw_header.is_a?(Array) ? raw_header : raw_header.to_s.split("\n")
    device_cookie_key = Authentication::Base::DEVICE_COOKIE_KEY
    device_line = cookie_lines.find { |line| line.start_with?("#{device_cookie_key}=") }

    assert_not_nil device_line, "Response should set device_id cookie (#{device_cookie_key})"
    # In test mode, secure flag is NOT set
    # In production mode (real production, not stubbed), secure flag IS set via Rails.env.production? check
  end

  test "device_id cookie roundtrips and validates against digest" do
    token_record = UserToken.create!(user: @user, device_id: @device_id)
    refresh_plain = token_record.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    # First call sets the cookie and rotates the refresh token
    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true, device_id: @device_id),
         as: :json

    assert_response :ok

    # Extract cookies from response (including the new refresh token)
    cookies_hash = extract_cookies_from_response

    # Use a fresh session for the second request
    s = open_session
    s.host!(@host)
    s.cookies[Authentication::Base::REFRESH_COOKIE_KEY] = cookies_hash[Authentication::Base::REFRESH_COOKIE_KEY]
    s.cookies[Authentication::Base::DEVICE_COOKIE_KEY] = cookies_hash[Authentication::Base::DEVICE_COOKIE_KEY]

    # Clear the header, rely on cookie
    s.post(
      "/edge/v0/token/refresh",
      headers: json_headers(with_csrf: true).merge("X-STRICT-DEVICE-CHECK" => "1"),
      as: :json,
    )

    assert_equal 200, s.response.status
  end

  private

  def json_headers(with_csrf:, device_id: nil)
    headers = { "Host" => @host, "Accept" => "application/json" }
    headers["X-CSRF-Token"] = csrf_token if with_csrf
    if device_id.present?
      headers["X-Device-Id"] = device_id
      cookies[Authentication::Base::DEVICE_COOKIE_KEY] = device_id
    end
    headers
  end

  def csrf_token
    @csrf_token ||= "test_csrf_token"
  end

  def with_cookie_domain_credentials(overrides)
    creds = Rails.app.creds
    fetch = ->(key, default: nil) { overrides.fetch(key, default) }

    creds.stub(:option, fetch) do
      yield
    end
  end
end
