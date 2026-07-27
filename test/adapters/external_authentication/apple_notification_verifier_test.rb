# frozen_string_literal: true

require "test_helper"

class AppleNotificationVerifierTest < ActiveSupport::TestCase
  test "verifies a signed consent-revoked notification and returns only minimum fields" do
    key = OpenSSL::PKey::RSA.generate(2048)
    now = Time.utc(2026, 7, 24, 12, 0, 0)
    token = JWT.encode(
      {
        iss: "https://appleid.apple.com",
        aud: "primary-app-id",
        iat: now.to_i,
        jti: "apple-notification-jti",
        events: { type: "consent-revoked", sub: "apple-subject", event_time: now.to_i },
      },
      key,
      "RS256",
      { kid: "apple-key" },
    )
    loader = ->(_options) { { keys: [JWT::JWK.new(key.public_key, kid: "apple-key").export] } }

    result = ExternalAuthentication::AppleNotificationVerifier.new(
      jws: token,
      audience: "primary-app-id",
      jwks_loader: loader,
      clock: -> { now },
    ).call

    assert_equal "apple-notification-jti", result.jti
    assert_equal "consent-revoked", result.event_type
    assert_equal "apple-subject", result.subject
    assert_equal now, result.occurred_at
  end

  test "rejects an unsupported signing algorithm before accepting the payload" do
    now = Time.utc(2026, 7, 24, 12, 0, 0)
    token = JWT.encode(
      {
        iss: "https://appleid.apple.com",
        aud: "primary-app-id",
        iat: now.to_i,
        jti: "apple-notification-jti",
        events: { type: "consent-revoked", sub: "apple-subject", event_time: now.to_i },
      },
      "secret",
      "HS256",
      { kid: "apple-key" },
    )

    error =
      assert_raises(ExternalAuthentication::AppleNotificationVerifier::VerificationError) do
        ExternalAuthentication::AppleNotificationVerifier.new(
          jws: token,
          audience: "primary-app-id",
          jwks_loader: ->(_options) { { keys: [] } },
          clock: -> { now },
        ).call
      end

    assert_equal :algorithm_invalid, error.code
  end

  test "rejects a notification without a JTI" do
    key = OpenSSL::PKey::RSA.generate(2048)
    now = Time.utc(2026, 7, 24, 12, 0, 0)
    token = JWT.encode(
      {
        iss: "https://appleid.apple.com",
        aud: "primary-app-id",
        iat: now.to_i,
        events: { type: "consent-revoked", sub: "apple-subject", event_time: now.to_i },
      },
      key,
      "RS256",
      { kid: "apple-key" },
    )
    loader = ->(_options) { { keys: [JWT::JWK.new(key.public_key, kid: "apple-key").export] } }

    error =
      assert_raises(ExternalAuthentication::AppleNotificationVerifier::VerificationError) do
        ExternalAuthentication::AppleNotificationVerifier.new(
          jws: token,
          audience: "primary-app-id",
          jwks_loader: loader,
          clock: -> { now },
        ).call
      end

    assert_equal :jti_missing, error.code
  end
end
