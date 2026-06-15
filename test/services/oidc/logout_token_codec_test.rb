# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcLogoutTokenCodecTest < ActiveSupport::TestCase
  setup do
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @previous_cache
  end

  test "encodes and verifies a back-channel logout token" do
    with_oidc_key("ACME_APP") do
      token = OidcLogoutTokenCodec.encode(
        client_id: "sign-rp",
        resource_type: "client",
        subject: "subject-1",
        sid: SecureRandom.uuid,
      )

      result = OidcLogoutTokenCodec.decode(
        logout_token: token,
        client_id: "sign-rp",
        resource_type: "client",
      )

      assert_predicate result, :success?
      assert_equal OidcLogoutTokenCodec::TOKEN_TYPE, result.payload.fetch("typ")
      assert result.payload.fetch("events").key?(OidcLogoutTokenCodec::EVENT_CLAIM)
      assert_not result.payload.key?("nonce")
    end
  end

  test "rejects replayed logout token jti" do
    with_oidc_key("ACME_APP") do
      token = OidcLogoutTokenCodec.encode(
        client_id: "sign-rp",
        resource_type: "client",
        subject: "subject-1",
        sid: SecureRandom.uuid,
      )

      assert_predicate OidcLogoutTokenCodec.decode(
        logout_token: token,
        client_id: "sign-rp",
        resource_type: "client",
      ), :success?
      assert_not OidcLogoutTokenCodec.decode(
        logout_token: token,
        client_id: "sign-rp",
        resource_type: "client",
      ).success?
    end
  end

  test "rejects an audience mismatch" do
    with_oidc_key("ACME_APP") do
      token = OidcLogoutTokenCodec.encode(
        client_id: "sign-rp",
        resource_type: "client",
        subject: "subject-1",
        sid: SecureRandom.uuid,
      )

      result = OidcLogoutTokenCodec.decode(
        logout_token: token,
        client_id: "core-next-rp",
        resource_type: "client",
      )

      assert_not_predicate result, :success?
    end
  end

  test "requires sid or subject" do
    with_oidc_key("ACME_APP") do
      assert_raises(ArgumentError) do
        OidcLogoutTokenCodec.encode(
          client_id: "sign-rp",
          resource_type: "client",
          subject: nil,
          sid: nil,
        )
      end
    end
  end

  private

  def with_oidc_key(namespace)
    key = OpenSSL::PKey::EC.generate("secp384r1")
    kid = "#{namespace.downcase.tr("_", "-")}-oidc-test"
    env = {
      "OIDC_CLIENT_#{namespace}_ACTIVE_KID" => kid,
      "OIDC_CLIENT_#{namespace}_PRIVATE_KEY" => Base64.strict_encode64(key.to_der),
    }
    previous = JitSecurityJwtRegistry.instance_variable_get(:@issuers)

    with_env(env) do
      JitSecurityJwtRegistry.reload!
      yield
    ensure
      JitSecurityJwtRegistry.instance_variable_set(:@issuers, previous)
    end
  end

  def with_env(values)
    previous = {}
    values.each do |key, value|
      previous[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
