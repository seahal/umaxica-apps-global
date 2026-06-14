# frozen_string_literal: true

require "test_helper"

class PalmAccessTokenAuthenticatorTest < ActiveSupport::TestCase
  HOST = "palm.jp.umaxica.app"

  test "accepts acme issued palm audience bearer token" do
    result = authenticate(token: palm_token)

    assert_predicate result, :success?
    assert_equal clients(:one), result.resource
    assert_equal "app-ios-rp", AuthorizationTokenClaims.client_id(result.payload)
  end

  test "rejects missing bearer token" do
    result = authenticate(token: nil)

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "rejects non bearer scheme" do
    result = authenticate(token: palm_token, scheme: "DPoP")

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "rejects wrong audience" do
    result = authenticate(token: palm_token(audiences: ["core-browser"]))

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "rejects missing palm read scope" do
    result = authenticate(token: palm_token(scopes: %w(openid profile)))

    assert_not result.success?
    assert_equal "insufficient_scope", result.error
  end

  test "rejects unsupported native client id" do
    result = authenticate(token: palm_token(client_id: "core-app"))

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "rejects unknown subject" do
    subject = "#{OidcSubject.prefix_for("client")}_missing-client"
    result = authenticate(token: palm_token(subject: subject))

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "rejects administratively locked client" do
    client = clients(:one)
    client.update!(
      access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED,
      admin_locked_at: Time.current,
      admin_locked_by_operator_id: operators(:one).id,
      admin_locked_reason_code: "security_incident",
    )

    result = authenticate(token: palm_token)

    assert_not result.success?
    assert_equal "invalid_token", result.error
  ensure
    client&.reload&.update!(
      access_state: AdministrativeAccessLockable::ACCESS_STATE_ENABLED,
      token_valid_after_at: nil,
      admin_locked_at: nil,
      admin_locked_by_operator_id: nil,
      admin_locked_reason_code: nil,
    )
  end

  private

  def authenticate(token:, scheme: "Bearer")
    PalmAccessTokenAuthenticator.call(
      access_token: token,
      host: HOST,
      authorization_scheme: scheme,
    )
  end

  def palm_token(client: clients(:one), scopes: %w(openid palm.read), audiences: [PalmAccessTokenAuthenticator::AUDIENCE],
                 client_id: "app-ios-rp", subject: nil)
    AuthenticationTokenService.encode(
      client,
      host: OidcIssuer.host_for_resource_type("client"),
      resource_type: "client",
      session_public_id: "palm-session",
      session_id: "palm-session",
      expires_at: 10.minutes.from_now,
      scopes: scopes,
      issuer: OidcIssuer.for_resource_type("client"),
      audiences: audiences,
      subject: subject || OidcSubject.for(client, resource_type: "client"),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
      client_id: client_id,
    )
  end
end
