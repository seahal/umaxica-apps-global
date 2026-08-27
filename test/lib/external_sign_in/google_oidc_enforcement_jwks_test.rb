# typed: false
# frozen_string_literal: true

require "test_helper"

class GoogleOidcEnforcementJwksTest < ActiveSupport::TestCase
  test "fetch_google_jwks returns parsed keys from a successful JWKS response" do
    subject = Object.new
    subject.extend(ExternalAuthenticationInfrastructureOmniauthGoogleOidcEnforcement)
    Rails.cache.delete(ExternalAuthenticationInfrastructureOmniauthGoogleOidcEnforcement::JWKS_CACHE_KEY)

    success = Net::HTTPSuccess.new("1.1", "200", "OK")
    success.define_singleton_method(:body) { '{"keys":[{"kid":"k1"}]}' }
    http = Object.new
    http.define_singleton_method(:request) { |_request| success }

    Net::HTTP.stub(:start, ->(*_args, **_kwargs, &block) { block.call(http) }) do
      jwks = subject.send(:fetch_google_jwks)

      assert_equal [{ "kid" => "k1" }], jwks.fetch("keys")
    end
  end

  test "google_jwks_loader refetches when the requested key is missing" do
    subject = Object.new
    subject.extend(ExternalAuthenticationInfrastructureOmniauthGoogleOidcEnforcement)
    Rails.cache.delete(ExternalAuthenticationInfrastructureOmniauthGoogleOidcEnforcement::JWKS_CACHE_KEY)

    success = Net::HTTPSuccess.new("1.1", "200", "OK")
    success.define_singleton_method(:body) { '{"keys":[{"kid":"k1"}]}' }
    requests = 0
    http = Object.new
    http.define_singleton_method(:request) do |_request|
      requests += 1
      success
    end

    Net::HTTP.stub(:start, ->(*_args, **_kwargs, &block) { block.call(http) }) do
      loader = subject.send(:google_jwks_loader)

      assert_equal [{ "kid" => "k1" }], loader.call.fetch("keys")
      assert_equal 1, requests

      assert_equal [{ "kid" => "k1" }], loader.call(kid_not_found: true).fetch("keys")
      assert_equal 2, requests
    end
  end

  test "fetch_google_jwks raises when Google returns a non-success response" do
    subject = Object.new
    subject.extend(ExternalAuthenticationInfrastructureOmniauthGoogleOidcEnforcement)
    Rails.cache.delete(ExternalAuthenticationInfrastructureOmniauthGoogleOidcEnforcement::JWKS_CACHE_KEY)

    failure = Net::HTTPResponse.new("1.1", "500", "ERR")
    http = Object.new
    http.define_singleton_method(:request) { |_request| failure }

    Net::HTTP.stub(:start, ->(*_args, **_kwargs, &block) { block.call(http) }) do
      error = assert_raises(JWT::DecodeError) { subject.send(:fetch_google_jwks) }

      assert_equal "Google JWKS fetch failed", error.message
    end
  end

  test "fetch_google_jwks raises when the JWKS body is not JSON" do
    subject = Object.new
    subject.extend(ExternalAuthenticationInfrastructureOmniauthGoogleOidcEnforcement)
    Rails.cache.delete(ExternalAuthenticationInfrastructureOmniauthGoogleOidcEnforcement::JWKS_CACHE_KEY)

    bad_json = Net::HTTPSuccess.new("1.1", "200", "OK")
    bad_json.define_singleton_method(:body) { "not-json" }
    http = Object.new
    http.define_singleton_method(:request) { |_request| bad_json }

    Net::HTTP.stub(:start, ->(*_args, **_kwargs, &block) { block.call(http) }) do
      error = assert_raises(JWT::DecodeError) { subject.send(:fetch_google_jwks) }

      assert_equal "JSON::ParserError", error.message
    end
  end

  test "fetch_google_jwks raises when keys is not an array" do
    subject = Object.new
    subject.extend(ExternalAuthenticationInfrastructureOmniauthGoogleOidcEnforcement)
    Rails.cache.delete(ExternalAuthenticationInfrastructureOmniauthGoogleOidcEnforcement::JWKS_CACHE_KEY)

    invalid_shape = Net::HTTPSuccess.new("1.1", "200", "OK")
    invalid_shape.define_singleton_method(:body) { '{"keys":"nope"}' }
    http = Object.new
    http.define_singleton_method(:request) { |_request| invalid_shape }

    Net::HTTP.stub(:start, ->(*_args, **_kwargs, &block) { block.call(http) }) do
      error = assert_raises(JWT::DecodeError) { subject.send(:fetch_google_jwks) }

      assert_equal "Google JWKS has an invalid shape", error.message
    end
  end
end
