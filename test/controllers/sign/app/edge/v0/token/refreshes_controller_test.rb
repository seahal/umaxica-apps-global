# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Edge::V0::Token::RefreshesControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_tokens, :client_occurrence_statuses

  setup do
    @user = clients(:one)
    @host = ENV.fetch("ID_SERVICE_URL", "test.umaxica.com")
    @csrf_token = nil
  end

  test "POST refresh with valid refresh token sets both access and refresh cookies" do
    # Create a token record and generate a refresh token
    token_record = ClientToken.create!(user: @user)
    refresh_plain = token_record.rotate_refresh_token!

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true),
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
      token_record = ClientToken.create!(user: @user)
      refresh_plain = token_record.rotate_refresh_token!
      cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

      with_cookie_domain_credentials(COOKIE_DOMAIN_APP: ".app.localhost") do
        if true # Replaced STUB stub with real execution as per G1
          post "/edge/v0/token/refresh",
               headers: json_headers(with_csrf: true),
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
      token_record = ClientToken.create!(user: @user)
      refresh_plain = token_record.rotate_refresh_token!
      cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

      with_cookie_domain_credentials(COOKIE_DOMAIN_APP: ".app.localhost") do
        if true # Replaced STUB stub with real execution as per G1
          post "/edge/v0/token/refresh",
               headers: json_headers(with_csrf: true),
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
    token_record = ClientToken.create!(user: @user)
    refresh_plain = token_record.rotate_refresh_token!

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    # First, refresh to get new tokens
    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true),
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

    assert json["authenticated"], "Client should be authenticated"
  end

  test "POST refresh with old refresh token after rotation returns 401" do
    # Create a token record and generate a refresh token
    token_record = ClientToken.create!(user: @user)
    old_refresh_plain = token_record.rotate_refresh_token!

    # Rotate once via endpoint
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = old_refresh_plain
    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true),
         as: :json

    assert_response :ok

    # Try to use the old refresh token
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = old_refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true),
         as: :json

    assert_response :unauthorized
    json = response.parsed_body

    assert_equal "invalid_refresh_token", json["error_code"]
    assert_equal "refresh_reuse_detected", ClientOccurrence.order(:id).last&.event_type
  end

  test "POST refresh with invalid verifier returns generic error without reuse occurrence" do
    token_record = ClientToken.create!(user: @user)
    refresh_plain = token_record.rotate_refresh_token!
    public_id, = ClientToken.parse_refresh_token(refresh_plain)
    forged_refresh = ClientToken.build_refresh_token(public_id, "wrong-verifier")

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = forged_refresh

    assert_no_difference("ClientOccurrence.where(event_type: 'refresh_reuse_detected').count") do
      post "/edge/v0/token/refresh",
           headers: json_headers(with_csrf: true),
           as: :json
    end

    assert_response :unauthorized
    json = response.parsed_body

    assert_equal "invalid_refresh_token", json["error_code"]
    assert_nil token_record.reload.rotated_at
    assert_operator token_record.discarded_at, :>, Time.current
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
    token_record = ClientToken.create!(user: @user)
    refresh_plain = token_record.rotate_refresh_token!
    token_record.update_columns(discarded_at: 1.day.ago)

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true),
         as: :json

    assert_response :unauthorized
  end

  test "POST refresh with revoked token returns 401" do
    # Create a token record and revoke it
    token_record = ClientToken.create!(user: @user)
    refresh_plain = token_record.rotate_refresh_token!
    token_record.revoke!

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true),
         as: :json

    assert_response :unauthorized
  end

  test "POST refresh for DPoP-bound token requires proof" do
    _private_key, jwk = generate_dpop_jwk
    jkt = Jit::Security::Jwt::ThumbprintCalculator.calculate(jwk)
    token_record = ClientToken.create!(user: @user, dpop_jkt: jkt)
    refresh_plain = token_record.rotate_refresh_token!

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true),
         as: :json

    assert_response :unauthorized
    assert_nil token_record.reload.rotated_at
    assert_equal "refresh_dpop_denied", ClientOccurrence.order(:id).last.event_type
  end

  test "POST refresh for DPoP-bound token rejects mismatched proof key" do
    _private_key, jwk = generate_dpop_jwk
    jkt = Jit::Security::Jwt::ThumbprintCalculator.calculate(jwk)
    attacker_key, attacker_jwk = generate_dpop_jwk
    token_record = ClientToken.create!(user: @user, dpop_jkt: jkt)
    refresh_plain = token_record.rotate_refresh_token!
    proof = build_dpop_proof(attacker_key, attacker_jwk, method: "POST", uri: "http://#{@host}/edge/v0/token/refresh")

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true).merge("DPoP" => proof),
         as: :json

    assert_response :unauthorized
    assert_nil token_record.reload.rotated_at
    occurrence = ClientOccurrence.order(:id).last

    assert_equal "refresh_dpop_denied", occurrence.event_type
    assert_equal "jkt_mismatch", occurrence.context["reason"]
  end

  test "POST refresh for DPoP-bound token preserves JKT after rotation" do
    private_key, jwk = generate_dpop_jwk
    jkt = Jit::Security::Jwt::ThumbprintCalculator.calculate(jwk)
    token_record = ClientToken.create!(user: @user, dpop_jkt: jkt)
    refresh_plain = token_record.rotate_refresh_token!
    proof = build_dpop_proof(private_key, jwk, method: "POST", uri: "http://#{@host}/edge/v0/token/refresh")

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true).merge("DPoP" => proof),
         as: :json

    assert_response :ok

    rotated_token = ClientToken.where(user_id: @user.id, rotated_at: nil).order(created_at: :desc).first
    access_token = extract_cookies_from_response[Authentication::Base::ACCESS_COOKIE_KEY]
    payload = Authentication::Base::Token.decode(access_token, host: @host, resource_type: "client")

    assert_equal jkt, rotated_token.dpop_jkt
    assert_equal jkt, payload.dig("cnf", "jkt")
  end

  test "POST refresh with restricted token returns 403 and does not rotate token" do
    token_record = ClientToken.create!(
      user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED,
    )
    refresh_plain = token_record.rotate_refresh_token!(discarded_at: 15.minutes.from_now)
    before_generation = token_record.refresh_token_generation
    before_digest = token_record.refresh_token_digest

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true),
         as: :json

    assert_response :forbidden
    json = response.parsed_body

    assert_equal "restricted_session", json["error_code"]

    token_record.reload

    assert_equal before_generation, token_record.refresh_token_generation
    assert_equal before_digest, token_record.refresh_token_digest
  end

  test "POST refresh with restricted token returns localized error message" do
    token_record = ClientToken.create!(
      user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED,
    )
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] =
      token_record.rotate_refresh_token!(discarded_at: 15.minutes.from_now)

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true),
         as: :json

    assert_response :forbidden

    json = response.parsed_body

    assert_equal I18n.t("sign.token_refresh.errors.restricted_session"), json["error"]
    assert_equal "restricted_session", json["error_code"]
  end

  test "refresh cookie contains a valid rotated token" do
    token_record = ClientToken.create!(user: @user)
    refresh_plain = token_record.rotate_refresh_token!

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true),
         as: :json

    assert_response :ok

    # The cookie value should be a valid refresh token (public_id.verifier format)
    new_value = cookies[Authentication::Base::REFRESH_COOKIE_KEY]

    assert_predicate new_value, :present?, "Refresh cookie should be present after rotation"

    public_id, verifier = ClientToken.parse_refresh_token(new_value)

    assert_predicate public_id, :present?, "Rotated refresh token should contain a public_id"
    assert_predicate verifier, :present?, "Rotated refresh token should contain a verifier"
  end

  test "access cookie uses correct TTL" do
    # Create a token record and generate a refresh token
    token_record = ClientToken.create!(user: @user)
    refresh_plain = token_record.rotate_refresh_token!

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    freeze_time do
      post "/edge/v0/token/refresh",
           headers: json_headers(with_csrf: true),
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
    token_record = ClientToken.create!(user: @user)
    refresh_plain = token_record.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: false),
         as: :json

    assert_response :ok
    json = response.parsed_body

    assert json["refreshed"]
  end

  test "POST refresh with cookie token and missing CSRF is rejected when forgery protection is enabled" do
    token_record = ClientToken.create!(user: @user)
    refresh_plain = token_record.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    with_forgery_protection do
      post "/edge/v0/token/refresh",
           headers: json_headers(with_csrf: false),
           as: :json
    end

    assert_response :unprocessable_content
    assert_nil token_record.reload.rotated_at
  end

  test "POST refresh rejects deactivated user even with valid refresh token" do
    @user.update!(
      deactivated_at: Time.current, withdrawal_started_at: 1.hour.ago,
      discarded_at: 30.days.from_now,
      purged_at: 31.days.from_now,
    )

    token_record = ClientToken.create!(user: @user)
    refresh_plain = token_record.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true),
         as: :json

    assert_includes [401, 403], response.status
    json = response.parsed_body

    assert_not json["refreshed"]
    assert_equal I18n.t("sign.token_refresh.errors.withdrawal_required"), json["error"]
    assert_equal "withdrawal_required", json["error_code"]
  end

  test "POST refresh logs out DBSC-bound device session when proof is missing" do
    token_record = dbsc_bound_token
    refresh_plain = token_record.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true).merge(
           Auth::IoKeys::Headers::DBSC_SESSION_ID => %("session-abc"),
         ),
         as: :json

    assert_response :unauthorized
    assert_predicate token_record.reload, :revoked?
    assert_predicate token_record.device_session.reload, :revoked?

    occurrence = ClientOccurrence.order(:id).last

    assert_equal "refresh_dbsc_denied", occurrence.event_type
    assert_equal "missing_proof", occurrence.context["reason"]
  end

  test "POST refresh logs out DBSC-bound device session when proof is invalid" do
    token_record = dbsc_bound_token
    refresh_plain = token_record.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true).merge(
           Auth::IoKeys::Headers::DBSC_SESSION_ID => %("session-abc"),
           Auth::IoKeys::Headers::DBSC_RESPONSE => "invalid-proof",
         ),
         as: :json

    assert_response :unauthorized
    assert_predicate token_record.reload, :revoked?
    assert_predicate token_record.device_session.reload, :revoked?

    occurrence = ClientOccurrence.order(:id).last

    assert_equal "refresh_dbsc_denied", occurrence.event_type
    assert_equal "invalid_proof", occurrence.context["reason"]
  end

  test "POST refresh accepts DBSC-bound device session with valid proof" do
    token_record = dbsc_bound_token
    refresh_plain = token_record.rotate_refresh_token!
    proof = generate_dbsc_proof(private_key: @dbsc_private_key, challenge: token_record.dbsc_challenge)
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain
    cookies[Authentication::Base::DBSC_COOKIE_KEY] = "session-abc"

    post "/edge/v0/token/refresh",
         headers: json_headers(with_csrf: true).merge(
           Auth::IoKeys::Headers::DBSC_SESSION_ID => %("session-abc"),
           Auth::IoKeys::Headers::DBSC_RESPONSE => proof,
         ),
         as: :json

    assert_response :ok
    assert_not token_record.device_session.reload.revoked?
  end

  private

  def json_headers(with_csrf:)
    headers = { "Host" => @host, "Accept" => "application/json" }
    headers["X-CSRF-Token"] = csrf_token if with_csrf
    headers
  end

  def csrf_token
    @csrf_token ||= "test_csrf_token"
  end

  def dbsc_bound_token
    @dbsc_private_key = OpenSSL::PKey::EC.generate("prime256v1")
    jwk = JWT::JWK.new(@dbsc_private_key, use: "sig", kid: SecureRandom.uuid)
    token = ClientToken.create!(
      user: @user,
      user_token_binding_method_id: ClientTokenBindingMethod::DBSC,
      user_token_dbsc_status_id: ClientTokenDbscStatus::ACTIVE,
      dbsc_session_id: "session-abc",
      dbsc_public_key: jwk.export,
      dbsc_challenge: SecureRandom.hex(16),
      dbsc_challenge_issued_at: Time.current,
    )
    token.device_session.bind_dbsc!(session_id: "session-abc")
    token
  end

  def generate_dbsc_proof(private_key:, challenge:)
    JWT.encode(
      {
        "jti" => challenge,
        "aud" => "http://#{@host}/edge/v0/token/dbsc",
        "iat" => Time.current.to_i,
      },
      private_key,
      "ES256",
      { "typ" => "dbsc+jwt" },
    )
  end

  def with_cookie_domain_credentials(overrides)
    creds = Rails.app.creds
    fetch = ->(key, default: nil) { overrides.fetch(key, default) }

    creds.stub(:option, fetch) do
      yield
    end
  end

  def generate_dpop_jwk
    ec = OpenSSL::PKey::EC.generate("prime256v1")
    jwk = JWT::JWK.new(ec).export
    [ec, jwk]
  end

  def build_dpop_proof(private_key, jwk, method:, uri:)
    payload = {
      "htm" => method,
      "htu" => uri,
      "iat" => Time.current.to_i,
      "jti" => SecureRandom.uuid,
    }
    JWT.encode(payload, private_key, "ES256", { "typ" => "dpop+jwt", "jwk" => jwk })
  end
end
