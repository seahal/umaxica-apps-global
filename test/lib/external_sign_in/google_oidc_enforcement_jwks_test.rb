# typed: false
# frozen_string_literal: true

require "test_helper"

class GoogleOidcEnforcementJwksTest < ActiveSupport::TestCase
  test "loads google jwks through cache and rejects invalid payloads" do
    subject = Object.new
    subject.extend(ExternalAuthenticationInfrastructureOmniauthGoogleOidcEnforcement)
    Rails.cache.delete(ExternalAuthenticationInfrastructureOmniauthGoogleOidcEnforcement::JWKS_CACHE_KEY)

    def stub_google_http(response)
      http = Object.new
      http.define_singleton_method(:request) { |_request| response }
      Net::HTTP.stub(:start, ->(*_args, **_kwargs, &_block) { _block.call(http) }) { yield }
    end

    success = Net::HTTPSuccess.new("1.1", "200", "OK")
    success.define_singleton_method(:body) { '{"keys":[{"kid":"k1"}]}' }
    stub_google_http(success) do
      jwks = subject.send(:fetch_google_jwks)

      assert_equal [{ "kid" => "k1" }], jwks.fetch("keys")
    end

    loader = subject.send(:google_jwks_loader)
    stub_google_http(success) do
      assert_equal [{ "kid" => "k1" }], loader.call.fetch("keys")
      loader.call(kid_not_found: true)
    end

    failure = Net::HTTPResponse.new("1.1", "500", "ERR")
    stub_google_http(failure) do
      error = assert_raises(JWT::DecodeError) { subject.send(:fetch_google_jwks) }

      assert_equal "Google JWKS fetch failed", error.message
    end

    bad_json = Net::HTTPSuccess.new("1.1", "200", "OK")
    bad_json.define_singleton_method(:body) { "not-json" }
    stub_google_http(bad_json) do
      error = assert_raises(JWT::DecodeError) { subject.send(:fetch_google_jwks) }

      assert_equal "JSON::ParserError", error.message
    end

    invalid_shape = Net::HTTPSuccess.new("1.1", "200", "OK")
    invalid_shape.define_singleton_method(:body) { '{"keys":"nope"}' }
    stub_google_http(invalid_shape) do
      error = assert_raises(JWT::DecodeError) { subject.send(:fetch_google_jwks) }

      assert_equal "Google JWKS has an invalid shape", error.message
    end
  end
end
