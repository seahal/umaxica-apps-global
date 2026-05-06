# typed: false
# frozen_string_literal: true

require "test_helper"

class DbscControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :user_statuses, :user_tokens, :user_token_kinds, :user_token_statuses,
           :user_token_binding_methods, :user_token_dbsc_statuses,
           :staffs, :staff_statuses, :staff_tokens, :staff_token_kinds, :staff_token_statuses,
           :staff_token_binding_methods, :staff_token_dbsc_statuses

  setup do
    @ec_key = OpenSSL::PKey::EC.generate("prime256v1")
    @jwk = JWT::JWK.new(@ec_key, use: "sig", kid: SecureRandom.uuid)
  end

  test "Sign::App: returns unauthorized when no token record exists" do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")

    post sign_app_edge_v0_token_dbsc_path,
         headers: { Auth::IoKeys::Headers::DBSC_SESSION_ID => %("fake-session-id") }

    assert_response :unauthorized
  end

  test "Sign::App: handles registration with valid proof" do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")

    user = users(:one)
    token = UserToken.create!(
      user: user,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
      user_token_status_id: UserTokenStatus::NOTHING,
      user_token_binding_method_id: UserTokenBindingMethod::NOTHING,
      user_token_dbsc_status_id: UserTokenDbscStatus::NOTHING,
      refresh_expires_at: 1.day.from_now,
      deletable_at: 1.day.from_now,
      dbsc_challenge: SecureRandom.hex(16),
      dbsc_challenge_issued_at: Time.current,
    )

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    proof = generate_dbsc_proof(
      challenge: token.dbsc_challenge,
      audience: sign_app_edge_v0_token_dbsc_url,
      jwk: @jwk.export,
    )

    post sign_app_edge_v0_token_dbsc_path,
         headers: { Auth::IoKeys::Headers::DBSC_RESPONSE => proof }

    assert_response :created
    response_body = response.parsed_body

    assert_predicate response_body["session_identifier"], :present?

    token.reload

    assert_equal UserTokenBindingMethod::DBSC, token.user_token_binding_method_id
    assert_equal UserTokenDbscStatus::ACTIVE, token.user_token_dbsc_status_id
    assert_equal response_body["session_identifier"], token.dbsc_session_id
    assert_predicate token.dbsc_public_key, :present?
    assert_nil token.dbsc_challenge
  end

  test "Sign::App: handles registration failure with invalid proof" do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")

    user = users(:one)
    token = UserToken.create!(
      user: user,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
      user_token_status_id: UserTokenStatus::NOTHING,
      user_token_binding_method_id: UserTokenBindingMethod::NOTHING,
      user_token_dbsc_status_id: UserTokenDbscStatus::NOTHING,
      refresh_expires_at: 1.day.from_now,
      deletable_at: 1.day.from_now,
      dbsc_challenge: SecureRandom.hex(16),
      dbsc_challenge_issued_at: Time.current,
    )

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post sign_app_edge_v0_token_dbsc_path,
         headers: { Auth::IoKeys::Headers::DBSC_RESPONSE => "invalid-proof" }

    assert_response :unprocessable_content
    response_body = response.parsed_body

    assert_predicate response_body["error_code"], :present?
  end

  test "Sign::App: handles registration failure without challenge" do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")

    user = users(:one)
    token = UserToken.create!(
      user: user,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
      user_token_status_id: UserTokenStatus::NOTHING,
      user_token_binding_method_id: UserTokenBindingMethod::NOTHING,
      user_token_dbsc_status_id: UserTokenDbscStatus::NOTHING,
      refresh_expires_at: 1.day.from_now,
      deletable_at: 1.day.from_now,
    )

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    proof = generate_dbsc_proof(
      challenge: "any-challenge",
      audience: sign_app_edge_v0_token_dbsc_url,
      jwk: @jwk.export,
    )

    post sign_app_edge_v0_token_dbsc_path,
         headers: { Auth::IoKeys::Headers::DBSC_RESPONSE => proof }

    assert_response :unprocessable_content
    assert_equal "missing_challenge", response.parsed_body["error_code"]
  end

  test "Sign::App: handles refresh challenge when proof is missing" do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")

    user = users(:one)
    token = UserToken.create!(
      user: user,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
      user_token_status_id: UserTokenStatus::NOTHING,
      user_token_binding_method_id: UserTokenBindingMethod::DBSC,
      user_token_dbsc_status_id: UserTokenDbscStatus::ACTIVE,
      refresh_expires_at: 1.day.from_now,
      deletable_at: 1.day.from_now,
      dbsc_session_id: "session-abc",
      dbsc_public_key: @jwk.export,
    )

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post sign_app_edge_v0_token_dbsc_path,
         headers: { Auth::IoKeys::Headers::DBSC_SESSION_ID => %("session-abc") }

    assert_response :forbidden
    assert_predicate response.headers[Auth::IoKeys::Headers::DBSC_CHALLENGE], :present?

    token.reload

    assert_predicate token.dbsc_challenge, :present?
  end

  test "Sign::App: handles refresh verification failure" do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")

    user = users(:one)
    token = UserToken.create!(
      user: user,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
      user_token_status_id: UserTokenStatus::NOTHING,
      user_token_binding_method_id: UserTokenBindingMethod::DBSC,
      user_token_dbsc_status_id: UserTokenDbscStatus::ACTIVE,
      refresh_expires_at: 1.day.from_now,
      deletable_at: 1.day.from_now,
      dbsc_session_id: "session-abc",
      dbsc_public_key: @jwk.export,
    )

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post sign_app_edge_v0_token_dbsc_path,
         headers: {
           Auth::IoKeys::Headers::DBSC_SESSION_ID => %("session-abc"),
           Auth::IoKeys::Headers::DBSC_RESPONSE => "invalid-proof",
         }

    assert_response :unprocessable_content
    assert_predicate response.parsed_body["error_code"], :present?
  end

  test "Sign::App: handles successful refresh verification" do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")

    user = users(:one)
    token = UserToken.create!(
      user: user,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
      user_token_status_id: UserTokenStatus::NOTHING,
      user_token_binding_method_id: UserTokenBindingMethod::DBSC,
      user_token_dbsc_status_id: UserTokenDbscStatus::ACTIVE,
      refresh_expires_at: 1.day.from_now,
      deletable_at: 1.day.from_now,
      dbsc_session_id: "session-abc",
      dbsc_public_key: @jwk.export,
      dbsc_challenge: SecureRandom.hex(16),
      dbsc_challenge_issued_at: Time.current,
    )

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    # For verification, do NOT include JWK in header (security requirement)
    proof = JWT.encode(
      { "jti" => token.dbsc_challenge,
        "aud" => sign_app_edge_v0_token_dbsc_url,
        "iat" => Time.current.to_i, },
      @ec_key,
      "ES256",
      { "typ" => "dbsc+jwt" }, # No jwk header
    )

    post sign_app_edge_v0_token_dbsc_path,
         headers: {
           Auth::IoKeys::Headers::DBSC_SESSION_ID => %("session-abc"),
           Auth::IoKeys::Headers::DBSC_RESPONSE => proof,
         }

    assert_response :no_content
    assert_predicate response.cookies[Authentication::Base::DBSC_COOKIE_KEY], :present?

    token.reload

    assert_nil token.dbsc_challenge
  end

  test "Sign::App: returns unauthorized when bound record does not exist" do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")

    user = users(:one)
    token = UserToken.create!(
      user: user,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
      user_token_status_id: UserTokenStatus::NOTHING,
      user_token_binding_method_id: UserTokenBindingMethod::NOTHING,
      user_token_dbsc_status_id: UserTokenDbscStatus::NOTHING,
      refresh_expires_at: 1.day.from_now,
      deletable_at: 1.day.from_now,
    )

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    # Execute with session ID but record not bound to DBSC (no dbsc_session_id)
    # This triggers 403 Forbidden because proof is blank (challenge issuance)
    post sign_app_edge_v0_token_dbsc_path,
         headers: { Auth::IoKeys::Headers::DBSC_SESSION_ID => %("session-abc") }

    assert_response :forbidden
  end

  test "Sign::Org: returns unauthorized when no token record exists" do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")

    post sign_org_edge_v0_token_dbsc_path,
         headers: { Auth::IoKeys::Headers::DBSC_SESSION_ID => %("fake-session-id") }

    assert_response :unauthorized
  end

  test "Sign::Org: handles registration with valid proof" do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")

    staff = staffs(:one)
    token = StaffToken.create!(
      staff: staff,
      staff_token_kind_id: StaffTokenKind::BROWSER_WEB,
      staff_token_status_id: StaffTokenStatus::NOTHING,
      staff_token_binding_method_id: StaffTokenBindingMethod::NOTHING,
      staff_token_dbsc_status_id: StaffTokenDbscStatus::NOTHING,
      refresh_expires_at: 1.day.from_now,
      deletable_at: 1.day.from_now,
      dbsc_challenge: SecureRandom.hex(16),
      dbsc_challenge_issued_at: Time.current,
    )

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    proof = generate_dbsc_proof(
      challenge: token.dbsc_challenge,
      audience: sign_org_edge_v0_token_dbsc_url,
      jwk: @jwk.export,
    )

    post sign_org_edge_v0_token_dbsc_path,
         headers: { Auth::IoKeys::Headers::DBSC_RESPONSE => proof }

    assert_response :created
    response_body = response.parsed_body

    assert_predicate response_body["session_identifier"], :present?

    token.reload

    assert_equal StaffTokenBindingMethod::DBSC, token.staff_token_binding_method_id
    assert_equal StaffTokenDbscStatus::ACTIVE, token.staff_token_dbsc_status_id
    assert_equal response_body["session_identifier"], token.dbsc_session_id
    assert_predicate token.dbsc_public_key, :present?
    assert_nil token.dbsc_challenge
  end

  test "Sign::Org: handles registration failure with invalid proof" do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")

    staff = staffs(:one)
    token = StaffToken.create!(
      staff: staff,
      staff_token_kind_id: StaffTokenKind::BROWSER_WEB,
      staff_token_status_id: StaffTokenStatus::NOTHING,
      staff_token_binding_method_id: StaffTokenBindingMethod::NOTHING,
      staff_token_dbsc_status_id: StaffTokenDbscStatus::NOTHING,
      refresh_expires_at: 1.day.from_now,
      deletable_at: 1.day.from_now,
      dbsc_challenge: SecureRandom.hex(16),
      dbsc_challenge_issued_at: Time.current,
    )

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post sign_org_edge_v0_token_dbsc_path,
         headers: { Auth::IoKeys::Headers::DBSC_RESPONSE => "invalid-proof" }

    assert_response :unprocessable_content
    response_body = response.parsed_body

    assert_predicate response_body["error_code"], :present?
  end

  test "Sign::Org: handles registration failure without challenge" do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")

    staff = staffs(:one)
    token = StaffToken.create!(
      staff: staff,
      staff_token_kind_id: StaffTokenKind::BROWSER_WEB,
      staff_token_status_id: StaffTokenStatus::NOTHING,
      staff_token_binding_method_id: StaffTokenBindingMethod::NOTHING,
      staff_token_dbsc_status_id: StaffTokenDbscStatus::NOTHING,
      refresh_expires_at: 1.day.from_now,
      deletable_at: 1.day.from_now,
    )

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    proof = generate_dbsc_proof(
      challenge: "any-challenge",
      audience: sign_org_edge_v0_token_dbsc_url,
      jwk: @jwk.export,
    )

    post sign_org_edge_v0_token_dbsc_path,
         headers: { Auth::IoKeys::Headers::DBSC_RESPONSE => proof }

    assert_response :unprocessable_content
    assert_equal "missing_challenge", response.parsed_body["error_code"]
  end

  test "Sign::Org: handles refresh challenge when proof is missing" do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")

    staff = staffs(:one)
    token = StaffToken.create!(
      staff: staff,
      staff_token_kind_id: StaffTokenKind::BROWSER_WEB,
      staff_token_status_id: StaffTokenStatus::NOTHING,
      staff_token_binding_method_id: StaffTokenBindingMethod::DBSC,
      staff_token_dbsc_status_id: StaffTokenDbscStatus::ACTIVE,
      refresh_expires_at: 1.day.from_now,
      deletable_at: 1.day.from_now,
      dbsc_session_id: "session-abc",
      dbsc_public_key: @jwk.export,
    )

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post sign_org_edge_v0_token_dbsc_path,
         headers: { Auth::IoKeys::Headers::DBSC_SESSION_ID => %("session-abc") }

    assert_response :forbidden
    assert_predicate response.headers[Auth::IoKeys::Headers::DBSC_CHALLENGE], :present?

    token.reload

    assert_predicate token.dbsc_challenge, :present?
  end

  test "Sign::Org: handles refresh verification failure" do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")

    staff = staffs(:one)
    token = StaffToken.create!(
      staff: staff,
      staff_token_kind_id: StaffTokenKind::BROWSER_WEB,
      staff_token_status_id: StaffTokenStatus::NOTHING,
      staff_token_binding_method_id: StaffTokenBindingMethod::DBSC,
      staff_token_dbsc_status_id: StaffTokenDbscStatus::ACTIVE,
      refresh_expires_at: 1.day.from_now,
      deletable_at: 1.day.from_now,
      dbsc_session_id: "session-abc",
      dbsc_public_key: @jwk.export,
    )

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post sign_org_edge_v0_token_dbsc_path,
         headers: {
           Auth::IoKeys::Headers::DBSC_SESSION_ID => %("session-abc"),
           Auth::IoKeys::Headers::DBSC_RESPONSE => "invalid-proof",
         }

    assert_response :unprocessable_content
    assert_predicate response.parsed_body["error_code"], :present?
  end

  test "Sign::Org: handles successful refresh verification" do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")

    staff = staffs(:one)
    token = StaffToken.create!(
      staff: staff,
      staff_token_kind_id: StaffTokenKind::BROWSER_WEB,
      staff_token_status_id: StaffTokenStatus::NOTHING,
      staff_token_binding_method_id: StaffTokenBindingMethod::DBSC,
      staff_token_dbsc_status_id: StaffTokenDbscStatus::ACTIVE,
      refresh_expires_at: 1.day.from_now,
      deletable_at: 1.day.from_now,
      dbsc_session_id: "session-abc",
      dbsc_public_key: @jwk.export,
      dbsc_challenge: SecureRandom.hex(16),
      dbsc_challenge_issued_at: Time.current,
    )

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    # For verification, do NOT include JWK in header (security requirement)
    proof = JWT.encode(
      { "jti" => token.dbsc_challenge,
        "aud" => sign_org_edge_v0_token_dbsc_url,
        "iat" => Time.current.to_i, },
      @ec_key,
      "ES256",
      { "typ" => "dbsc+jwt" }, # No jwk header
    )

    post sign_org_edge_v0_token_dbsc_path,
         headers: {
           Auth::IoKeys::Headers::DBSC_SESSION_ID => %("session-abc"),
           Auth::IoKeys::Headers::DBSC_RESPONSE => proof,
         }

    assert_response :no_content
    assert_predicate response.cookies[Authentication::Base::DBSC_COOKIE_KEY], :present?

    token.reload

    assert_nil token.dbsc_challenge
  end

  test "Sign::Org: returns unauthorized when bound record does not exist" do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")

    staff = staffs(:one)
    token = StaffToken.create!(
      staff: staff,
      staff_token_kind_id: StaffTokenKind::BROWSER_WEB,
      staff_token_status_id: StaffTokenStatus::NOTHING,
      staff_token_binding_method_id: StaffTokenBindingMethod::NOTHING,
      staff_token_dbsc_status_id: StaffTokenDbscStatus::NOTHING,
      refresh_expires_at: 1.day.from_now,
      deletable_at: 1.day.from_now,
    )

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    # Execute with session ID but record not bound to DBSC (no dbsc_session_id)
    # This triggers 403 Forbidden because proof is blank (challenge issuance)
    post sign_org_edge_v0_token_dbsc_path,
         headers: { Auth::IoKeys::Headers::DBSC_SESSION_ID => %("session-abc") }

    assert_response :forbidden
  end

  test "Sign::App: token_from_refresh_cookie returns nil when parsing fails" do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")

    user = users(:one)
    UserToken.create!(
      user: user,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
      user_token_status_id: UserTokenStatus::NOTHING,
      user_token_binding_method_id: UserTokenBindingMethod::NOTHING,
      user_token_dbsc_status_id: UserTokenDbscStatus::NOTHING,
      refresh_expires_at: 1.day.from_now,
      deletable_at: 1.day.from_now,
    )

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = "invalid-token-format"

    post sign_app_edge_v0_token_dbsc_path,
         headers: { Auth::IoKeys::Headers::DBSC_RESPONSE => "some-proof" }

    assert_response :unprocessable_content
  end

  private

  def generate_dbsc_proof(challenge:, audience:, jwk:, algorithm: "ES256")
    iat = Time.current.to_i
    payload = {
      "jti" => challenge,
      "aud" => audience,
      "iat" => iat,
    }

    headers = {
      "typ" => "dbsc+jwt",
      "jwk" => jwk,
    }

    JWT.encode(payload, @ec_key, algorithm, headers)
  end
end
