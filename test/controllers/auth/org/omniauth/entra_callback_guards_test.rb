# typed: false
# frozen_string_literal: true

require "test_helper"

# The staff Entra callback runs three guards before any session is issued: the
# provider must still be enabled for this surface, the resolved operator must
# still be allowed to sign in, and anything unexpected must end as a named
# internal error rather than a 500 that leaks the cause to the browser.
class Auth::Org::Omniauth::EntraCallbackGuardsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < Auth::Org::Omniauth::OmniauthCallbacksController
    attr_accessor :entra_error, :failures, :auth_hash, :allowed, :available

    def initialize
      super
      @failures = []
      @allowed = true
      @available = true
    end

    def request = Struct.new(:env, :remote_ip).new({ "omniauth.auth" => auth_hash }, "203.0.113.5")

    def external_authentication_allowed?(**) = allowed

    def external_authentication_callback_available?(**) = available

    def render_entra_error(reason)
      self.entra_error = reason
    end

    def log_entra_failure(event, **context)
      failures << [event, context]
    end
  end

  def auth_hash
    OmniAuth::AuthHash.new(provider: "entra", uid: "entra-uid", info: { email: "staff@example.com" })
  end

  test "a callback for a provider this surface has switched off is refused as unavailable" do
    harness = Harness.new
    harness.auth_hash = auth_hash
    harness.allowed = false

    harness.omniauth

    assert_equal :provider_unavailable, harness.entra_error
  end

  test "a resolution that names no operator allowed to sign in is refused and recorded" do
    harness = Harness.new
    harness.auth_hash = auth_hash
    resolution = Struct.new(:identity, :operator).new(Struct.new(:operator_id).new(7), nil)
    callback = Struct.new(:failed?, :principal).new(false, Struct.new(:tenant_context).new(nil))

    adapter = Object.new
    adapter.define_singleton_method(:call) { |**| callback }
    resolver = Object.new
    resolver.define_singleton_method(:call) { resolution }

    ExternalAuthentication::ProviderAdapterFactory.stub(:build, ->(**) { adapter }) do
      ExternalSignIn::OrgEntraResolver.stub(:new, ->(**) { resolver }) do
        harness.omniauth
      end
    end

    assert_equal :operator_not_found, harness.entra_error
    assert_equal "operator_not_allowed", harness.failures.first.first
  end

  test "an unexpected failure is recorded and answered as an internal error" do
    harness = Harness.new
    harness.auth_hash = auth_hash
    exploding = ->(**) { raise IOError, "provider adapter unavailable" }

    ExternalAuthentication::ProviderAdapterFactory.stub(:build, exploding) do
      harness.omniauth
    end

    assert_equal :internal_error, harness.entra_error
    assert_equal "internal_error", harness.failures.first.first
  end
end
