# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
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

  test "issue returns nil when local key refresh still cannot resolve the configured key" do
    with_env(
      "OIDC_CLIENT_BASE_APP_ACTIVE_KID" => nil,
      "OIDC_CLIENT_BASE_APP_PRIVATE_KEY" => nil,
      "OIDC_CLIENT_BASE_APP_PUBLIC_KEYSET" => nil,
    ) do
      JitSecurityJwtRegistry.reload!

      OidcClientAssertionJwt.stub(:refresh_local_key_material!, true) do
        OidcClientAssertionJwt.stub(
          :issue_with_configured_key, ->(**) {
                                        raise JitSecurityJwtRegistry::ConfigurationError
                                      },
        ) do
          assert_nil OidcClientAssertionJwt.issue(client_id: "base-rails-rp", token_url: "https://id.example/token")
        end
      end
    end
  end

  test "issue refreshes local key material once when the registry is missing a client assertion key" do
    token_url = "https://log.umaxica.app/oauth/token"
    key = OpenSSL::PKey::EC.generate("secp384r1")
    previous = JitSecurityJwtRegistry.instance_variable_get(:@issuers)
    installed = false

    with_env(
      "OIDC_CLIENT_BASE_APP_ACTIVE_KID" => nil,
      "OIDC_CLIENT_BASE_APP_PRIVATE_KEY" => nil,
      "OIDC_CLIENT_BASE_APP_PUBLIC_KEYSET" => nil,
    ) do
      JitSecurityJwtRegistry.reload!

      assert_nil JitSecurityJwtRegistry.private_key_for("oidc_client:BASE_APP")

      installer =
        lambda do |**|
          installed = true
          ENV["OIDC_CLIENT_BASE_APP_ACTIVE_KID"] = "base-app-oidc-recovered"
          ENV["OIDC_CLIENT_BASE_APP_PRIVATE_KEY"] = Base64.strict_encode64(key.to_der)
          true
        end

      JitSecurityJwtLocalKeysetInstaller.stub(:install!, installer) do
        assertion = OidcClientAssertionJwt.issue(client_id: "base-rails-rp", token_url: token_url)

        assert installed
        assert_predicate assertion, :present?
      end
    ensure
      JitSecurityJwtRegistry.instance_variable_set(:@issuers, previous)
    end
  end

  test "valid? rejects an assertion with the wrong audience" do
    token_url = "https://log.umaxica.app/oauth/token"

    with_oidc_client_key("CORE_APP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-next-rp", token_url: token_url)

      assert_not OidcClientAssertionJwt.valid?(
        client_id: "core-next-rp",
        assertion: assertion,
        token_url: "https://log.umaxica.app/oauth/token-alt",
      )
    end
  end

  test "valid? rejects an assertion for another client id" do
    token_url = "https://log.umaxica.app/oauth/token"

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
    token_url = "https://log.umaxica.app/oauth/token"

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
    token_url = "https://log.umaxica.app/oauth/token"

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

  test "runtime replay protection persists the consumed jti in PostgreSQL" do
    token_url = "https://log.umaxica.app/oauth/token"

    with_oidc_client_key("CORE_APP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-next-rp", token_url: token_url)

      assert OidcClientAssertionJwt.valid?(
        client_id: "core-next-rp",
        assertion: assertion,
        token_url: token_url,
        replay_store: SecurityConsumedJti,
      )
      assert SecurityConsumedJti.exists?(
        purpose: SecurityConsumedJti::PURPOSES.fetch(:oidc_client_assertion),
        issuer: "CORE_APP:core-next-rp",
      )
    end
  end

  test "valid? rejects an expired assertion" do
    token_url = "https://log.umaxica.app/oauth/token"

    with_oidc_client_key("CORE_APP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-next-rp", token_url: token_url, now: 1.hour.ago)

      assert_not OidcClientAssertionJwt.valid?(
        client_id: "core-next-rp",
        assertion: assertion,
        token_url: token_url,
      )
    end
  end

  test "valid? rejects an assertion issued in the future" do
    token_url = "https://log.umaxica.app/oauth/token"

    with_oidc_client_key("CORE_APP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-next-rp", token_url: token_url, now: 1.hour.from_now)

      assert_not OidcClientAssertionJwt.valid?(
        client_id: "core-next-rp",
        assertion: assertion,
        token_url: token_url,
      )
    end
  end

  test "valid? rejects an assertion signed by a key that is not registered for the client" do
    token_url = "https://log.umaxica.app/oauth/token"
    assertion = nil

    with_oidc_client_key("CORE_APP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-next-rp", token_url: token_url)
    end

    # Registering a fresh key under the same kid means the original signature no
    # longer matches any key registered for the client.
    with_oidc_client_key("CORE_APP") do
      assert_not OidcClientAssertionJwt.valid?(
        client_id: "core-next-rp",
        assertion: assertion,
        token_url: token_url,
      )
    end
  end

  test "valid? fails closed when the replay store is unavailable" do
    token_url = "https://log.umaxica.app/oauth/token"

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
