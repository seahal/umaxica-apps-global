# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalSignIn::EntraJwksCacheTest < ActiveSupport::TestCase
  TENANT_ID = "11111111-2222-3333-4444-555555555555"
  JWKS_URL = "https://login.microsoftonline.com/#{TENANT_ID}/discovery/v2.0/keys"

  test "returns and caches a valid JWKS document" do
    cache = ActiveSupport::Cache::MemoryStore.new
    requests = 0
    stubs =
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.get(JWKS_URL) do
          requests += 1
          [200, {}, JSON.generate("keys" => [{ "kid" => "key-1" }])]
        end
      end

    Rails.stub(:cache, cache) do
      stub_outbound_http(stubs) do
        loader = ExternalSignIn::EntraJwksCache.new(tenant_id: TENANT_ID).loader

        assert_equal({ "keys" => [{ "kid" => "key-1" }] }, loader.call({}))
        assert_equal({ "keys" => [{ "kid" => "key-1" }] }, loader.call({}))
      end
    end

    assert_equal 1, requests
  end

  test "invalidates the cached JWKS when the requested key is missing" do
    cache = ActiveSupport::Cache::MemoryStore.new
    requests = 0
    stubs =
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.get(JWKS_URL) do
          requests += 1
          [200, {}, JSON.generate("keys" => [{ "kid" => "key-#{requests}" }])]
        end
      end

    Rails.stub(:cache, cache) do
      stub_outbound_http(stubs) do
        loader = ExternalSignIn::EntraJwksCache.new(tenant_id: TENANT_ID).loader

        assert_equal "key-1", loader.call({}).fetch("keys").first.fetch("kid")
        assert_equal "key-2", loader.call(kid_not_found: true).fetch("keys").first.fetch("kid")
      end
    end

    assert_equal 2, requests
  end

  test "raises FetchError for a non-success HTTP response" do
    assert_fetch_error { [502, {}, "upstream unavailable"] }
  end

  test "raises FetchError for invalid JSON and invalid JWKS shape" do
    assert_fetch_error { [200, {}, "not-json"] }
    assert_fetch_error { [200, {}, JSON.generate("keys" => "not-an-array")] }
  end

  test "raises FetchError when the JWKS response body is missing" do
    assert_fetch_error { [200, {}, nil] }
  end

  # Faraday reports a read timeout as Faraday::TimeoutError rather than the
  # Net::ReadTimeout the previous stub raised. The point of the test is that a
  # transport failure still surfaces as FetchError and never as a raw error from
  # the HTTP layer.
  test "raises FetchError for transport failures" do
    assert_fetch_error { raise Faraday::TimeoutError, "read timeout" }
    assert_fetch_error { raise Faraday::ConnectionFailed, "connection refused" }
    assert_fetch_error { raise Faraday::SSLError, "certificate verify failed" }
  end

  private

  def assert_fetch_error(&)
    stubs = Faraday::Adapter::Test::Stubs.new { |stub| stub.get(JWKS_URL, &) }

    stub_outbound_http(stubs) do
      assert_raises(ExternalSignIn::EntraJwksCache::FetchError) do
        ExternalSignIn::EntraJwksCache.new(tenant_id: TENANT_ID).loader.call({})
      end
    end

    stubs.verify_stubbed_calls
  end
end
