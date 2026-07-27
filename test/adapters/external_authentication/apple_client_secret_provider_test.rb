# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationAppleClientSecretProviderTest < ActiveSupport::TestCase
  APPLE_ISSUER = "https://appleid.apple.com"

  test "signs a short-lived client secret JWT without retaining it" do
    key = OpenSSL::PKey::EC.generate("prime256v1")
    now = Time.utc(2026, 7, 24, 12, 0, 0)
    provider = ExternalAuthentication::AppleClientSecretProvider.new(
      client_id: "com.example.web",
      team_id: "TEAMID1234",
      key_id: "KEYID12345",
      private_key_pem: key.to_pem,
      clock: -> { now },
    )

    token = provider.call
    decoded = JSON::JWT.decode(token, :skip_verification)

    assert_equal "TEAMID1234", decoded[:iss]
    assert_equal "com.example.web", decoded[:sub]
    assert_equal APPLE_ISSUER, decoded[:aud]
    assert_equal now.to_i, decoded[:iat]
    assert_equal 5.minutes.from_now(now).to_i, decoded[:exp]
    assert_equal "KEYID12345", decoded.header[:kid]
    assert_predicate provider, :private_key_configured?
  end

  test "rejects a client secret lifetime longer than Apple permits" do
    key = OpenSSL::PKey::EC.generate("prime256v1")

    error =
      assert_raises(ArgumentError) do
        ExternalAuthentication::AppleClientSecretProvider.new(
          client_id: "com.example.web",
          team_id: "TEAMID1234",
          key_id: "KEYID12345",
          private_key_pem: key.to_pem,
          ttl: 181.days,
        )
      end

    assert_equal "ttl must not exceed 180 days", error.message
  end
end
