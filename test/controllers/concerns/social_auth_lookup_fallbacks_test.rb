# typed: false
# frozen_string_literal: true

require "test_helper"

# Social identity lookup runs on data the provider controls, so a provider error
# or an argument the repository rejects must resolve to "no identity" rather
# than aborting the callback. The request-method reader is used only for audit
# lines and must never be the reason a callback fails.
class SocialAuthLookupFallbacksTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    include SocialAuth

    attr_accessor :request_double

    def request = request_double

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
  end

  test "a repository that rejects the principal resolves to no identity" do
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: "sub-1",
      issuer: "https://accounts.google.com",
      audience: "client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google/1.0.0",
    )
    exploding = Object.new
    exploding.define_singleton_method(:build) { |_provider| raise ArgumentError, "unsupported provider" }

    ExternalAuthentication::IdentityRepositoryFactory.stub(:current, exploding) do
      assert_nil @harness.invoke(:social_auth_identity_for_callback, principal)
    end
  end

  test "a request that cannot report its method resolves to none rather than raising" do
    @harness.request_double = Object.new
    @harness.request_double.define_singleton_method(:respond_to?) { |*| raise IOError, "request gone" }

    assert_nil @harness.invoke(:social_auth_request_method)
  end
end
