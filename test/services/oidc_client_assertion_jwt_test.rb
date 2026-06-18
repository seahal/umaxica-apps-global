# frozen_string_literal: true

require "test_helper"
require "base64"

class OidcClientAssertionJwtTest < ActiveSupport::TestCase
  class RaisingReplayStore
    def write(*)
      raise StandardError, "cache unavailable"
    end
  end

  setup do
    @previous_replay_store = OidcClientAssertionJwt.replay_store
    OidcClientAssertionJwt.replay_store = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    OidcClientAssertionJwt.replay_store = @previous_replay_store
  end

  test "issue returns nil when the client is not registered" do
    assert_nil OidcClientAssertionJwt.issue(client_id: "missing_client", token_url: "https://id.example/token")
  end

  test "valid? rejects an assertion with the wrong audience" do
    token_url = "https://id.umaxica.app/oauth/token"

    with_oidc_client_key("CORE_APP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-next-rp", token_url: token_url)

      assert_not OidcClientAssertionJwt.valid?(
        client_id: "core-next-rp",
        assertion: assertion,
        token_url: "https://id.umaxica.app/oauth/token-alt",
      )
    end
  end

  test "valid? rejects an assertion for another client id" do
    token_url = "https://id.umaxica.app/oauth/token"

    with_oidc_client_key("CORE_APP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-next-rp", token_url: token_url)

      assert_not OidcClientAssertionJwt.valid?(
        client_id: "docs_app",
        assertion: assertion,
        token_url: token_url,
      )
    end
  end

  test "valid? accepts a matching assertion" do
    token_url = "https://id.umaxica.app/oauth/token"

    with_oidc_client_key("CORE_APP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-next-rp", token_url: token_url)

      assert OidcClientAssertionJwt.valid?(
        client_id: "core-next-rp",
        assertion: assertion,
        token_url: token_url,
      )
    end
  end

  test "valid? rejects a replayed assertion jti" do
    token_url = "https://id.umaxica.app/oauth/token"

    with_oidc_client_key("CORE_APP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-next-rp", token_url: token_url)

      assert OidcClientAssertionJwt.valid?(
        client_id: "core-next-rp",
        assertion: assertion,
        token_url: token_url,
      )
      assert_not OidcClientAssertionJwt.valid?(
        client_id: "core-next-rp",
        assertion: assertion,
        token_url: token_url,
      )
    end
  end

  test "valid? fails closed when the replay store is unavailable" do
    token_url = "https://id.umaxica.app/oauth/token"

    with_oidc_client_key("CORE_APP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-next-rp", token_url: token_url)

      assert_not OidcClientAssertionJwt.valid?(
        client_id: "core-next-rp",
        assertion: assertion,
        token_url: token_url,
        replay_store: RaisingReplayStore.new,
      )
    end
  end

  private

  def with_oidc_client_key(namespace)
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
