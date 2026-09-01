# typed: false
# frozen_string_literal: true

require "test_helper"

# Authorize-endpoint rate limits are counted per surface, per client and per
# redirect host. A redirect_uri the URI parser rejects must not take the request
# down and must not collapse every client into one bucket -- it counts as an
# unknown host instead.
class OauthAuthorizeRateLimitKeysTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < ActionController::Base
    include OauthAuthorizeRateLimit

    attr_accessor :params_hash

    def self.name = "Base::Com::Oauth::AuthorizationsController"

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
  end

  test "a redirect_uri the parser rejects resolves to no host rather than raising" do
    @harness.params_hash = { redirect_uri: "https://[" }

    assert_nil @harness.invoke(:oauth_authorize_rate_limit_redirect_uri_host)
  end

  test "a well-formed redirect_uri contributes its host to the bucket key" do
    @harness.params_hash = { redirect_uri: "https://rp.example/callback", client_id: "rp-1" }

    assert_equal "rp.example", @harness.invoke(:oauth_authorize_rate_limit_redirect_uri_host)

    key = @harness.invoke(:oauth_authorize_rate_limit_client_redirect_host_key)

    assert_includes key, "rp.example"
    assert_includes key, "rp-1"
    assert_includes key, "com"
  end

  test "a request with no client id is counted under an unknown client rather than merged" do
    @harness.params_hash = { redirect_uri: "https://rp.example/callback" }

    assert_includes @harness.invoke(:oauth_authorize_rate_limit_client_redirect_host_key), "unknown"
  end
end
