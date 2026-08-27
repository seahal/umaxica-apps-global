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

  test "rejects malformed tokens missing kids invalid events and stale issued at" do
    now = Time.utc(2026, 7, 24, 12, 0, 0)
    key = OpenSSL::PKey::RSA.generate(2048)
    loader = ->(_options) { { keys: [JWT::JWK.new(key.public_key, kid: "apple-key").export] } }

    malformed =
      assert_raises(ExternalAuthentication::AppleNotificationVerifier::VerificationError) do
        ExternalAuthentication::AppleNotificationVerifier.new(
          jws: "not.a.jws",
          audience: "primary-app-id",
          jwks_loader: loader,
          clock: -> { now },
        ).call
      end
    assert_equal :malformed_jws, malformed.code

    missing_kid = JWT.encode(
      { iss: "https://appleid.apple.com",
        aud: "primary-app-id",
        iat: now.to_i,
        jti: "jti",
        events: { type: "consent-revoked", sub: "apple-subject", event_time: now.to_i }, },
      key,
      "RS256",
    )
    kid_error =
      assert_raises(ExternalAuthentication::AppleNotificationVerifier::VerificationError) do
        ExternalAuthentication::AppleNotificationVerifier.new(
          jws: missing_kid,
          audience: "primary-app-id",
          jwks_loader: loader,
          clock: -> { now },
        ).call
      end
    assert_equal :kid_missing, kid_error.code

    bad_events = JWT.encode(
      { iss: "https://appleid.apple.com", aud: "primary-app-id", iat: now.to_i, jti: "jti", events: "nope" },
      key,
      "RS256",
      { kid: "apple-key" },
    )
    events_error =
      assert_raises(ExternalAuthentication::AppleNotificationVerifier::VerificationError) do
        ExternalAuthentication::AppleNotificationVerifier.new(
          jws: bad_events,
          audience: "primary-app-id",
          jwks_loader: loader,
          clock: -> { now },
        ).call
      end
    assert_equal :events_invalid, events_error.code

    bad_type = JWT.encode(
      { iss: "https://appleid.apple.com",
        aud: "primary-app-id",
        iat: now.to_i,
        jti: "jti",
        events: { type: "unknown", sub: "apple-subject", event_time: now.to_i }, },
      key,
      "RS256",
      { kid: "apple-key" },
    )
    type_error =
      assert_raises(ExternalAuthentication::AppleNotificationVerifier::VerificationError) do
        ExternalAuthentication::AppleNotificationVerifier.new(
          jws: bad_type,
          audience: "primary-app-id",
          jwks_loader: loader,
          clock: -> { now },
        ).call
      end
    assert_equal :event_type_invalid, type_error.code

    future = JWT.encode(
      { iss: "https://appleid.apple.com",
        aud: "primary-app-id",
        iat: now.to_i + 1.hour.to_i,
        jti: "jti",
        events: { type: "consent-revoked", sub: "apple-subject", event_time: now.to_i }, },
      key,
      "RS256",
      { kid: "apple-key" },
    )
    future_error =
      assert_raises(ExternalAuthentication::AppleNotificationVerifier::VerificationError) do
        ExternalAuthentication::AppleNotificationVerifier.new(
          jws: future,
          audience: "primary-app-id",
          jwks_loader: loader,
          clock: -> { now },
        ).call
      end
    assert_equal :issued_at_future, future_error.code

    expired = JWT.encode(
      { iss: "https://appleid.apple.com",
        aud: "primary-app-id",
        iat: now.to_i - 48.hours.to_i,
        jti: "jti",
        events: { type: "consent-revoked", sub: "apple-subject", event_time: now.to_i }, },
      key,
      "RS256",
      { kid: "apple-key" },
    )
    expired_error =
      assert_raises(ExternalAuthentication::AppleNotificationVerifier::VerificationError) do
        ExternalAuthentication::AppleNotificationVerifier.new(
          jws: expired,
          audience: "primary-app-id",
          jwks_loader: loader,
          clock: -> { now },
        ).call
      end
    assert_equal :issued_at_expired, expired_error.code
  end

  test "from_credentials requires a string audience" do
    Rails.app.creds.stub(:option, nil) do
      assert_raises(ExternalAuthentication::AppleNotificationVerifier::ConfigurationError) do
        ExternalAuthentication::AppleNotificationVerifier.from_credentials(jws: "token")
      end
    end
  end

  test "initialize requires a callable jwks loader" do
    assert_raises(ArgumentError) do
      ExternalAuthentication::AppleNotificationVerifier.new(
        jws: "token",
        audience: "primary-app-id",
        jwks_loader: Object.new,
      )
    end
  end
end
