# typed: false
# frozen_string_literal: true

require "test_helper"

class GoogleOidcEnforcementJwksTest < ActiveSupport::TestCase
  ENFORCEMENT = ExternalAuthenticationInfrastructureOmniauthGoogleOidcEnforcement

  setup do
    @subject = Object.new
    @subject.extend(ENFORCEMENT)
    Rails.cache.delete(ENFORCEMENT::JWKS_CACHE_KEY)
  end

  test "loads google jwks through the cache" do
    stubs = stub_google_jwks { [200, {}, '{"keys":[{"kid":"k1"}]}'] }

    stub_outbound_http(stubs) do
      assert_equal [{ "kid" => "k1" }], @subject.send(:fetch_google_jwks).fetch("keys")

      loader = @subject.send(:google_jwks_loader)

      assert_equal [{ "kid" => "k1" }], loader.call.fetch("keys")
      loader.call(kid_not_found: true)
    end
  end

  test "rejects a non-success response" do
    assert_decode_error("Google JWKS fetch failed") { [500, {}, "ERR"] }
  end

  test "rejects a body that is not JSON" do
    assert_decode_error("JSON::ParserError") { [200, {}, "not-json"] }
  end

  test "rejects a JWKS document of the wrong shape" do
    assert_decode_error("Google JWKS has an invalid shape") { [200, {}, '{"keys":"nope"}'] }
  end

  # Faraday reports transport failures through its own hierarchy; the message
  # carries the class name, which is what the enforcement module re-raises.
  test "rejects a transport failure" do
    assert_decode_error("Faraday::ConnectionFailed") { raise Faraday::ConnectionFailed, "refused" }
    assert_decode_error("Faraday::TimeoutError") { raise Faraday::TimeoutError, "read timeout" }
  end

  private

  def stub_google_jwks(&)
    Faraday::Adapter::Test::Stubs.new { |stub| stub.get(ENFORCEMENT::JWKS_URI.to_s, &) }
  end

  def assert_decode_error(message, &)
    stubs = stub_google_jwks(&)

    stub_outbound_http(stubs) do
      error = assert_raises(JWT::DecodeError) { @subject.send(:fetch_google_jwks) }

      assert_equal message, error.message
    end

    stubs.verify_stubbed_calls
  end
end
