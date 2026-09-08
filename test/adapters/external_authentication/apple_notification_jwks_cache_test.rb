# typed: false
# frozen_string_literal: true

require "test_helper"

class AppleNotificationJwksCacheTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
  end

  teardown do
    Rails.cache.clear
  end

  test "loader caches fetcher output and invalidates on kid_not_found" do
    calls = 0
    payload = { "keys" => [{ "kid" => "k1", "kty" => "RSA" }] }
    cache = ExternalAuthentication::AppleNotificationJwksCache.new(
      fetcher: lambda {
        calls += 1
        payload
      },
    )
    cache_store = ActiveSupport::Cache::MemoryStore.new

    Rails.stub(:cache, cache_store) do
      loader = cache.loader

      assert_equal payload, loader.call({})
      assert_equal payload, loader.call({})
      assert_equal 1, calls

      assert_equal payload, loader.call(kid_not_found: true)
    end

    assert_equal 2, calls
  end

  test "default fetch raises FetchError when HTTP response is not success" do
    assert_fetch_error { [400, {}, "nope"] }
  end

  test "default fetch raises FetchError for oversized or invalid JSON bodies" do
    oversized = "x" * (ExternalAuthentication::AppleNotificationJwksCache::MAXIMUM_RESPONSE_BYTES + 1)

    assert_fetch_error { [200, {}, oversized] }
    assert_fetch_error { [200, {}, "not-json"] }
    assert_fetch_error { [200, {}, '{"hello":[]}'] }
  end

  # Faraday reports transport failures through its own hierarchy, so the cache
  # has to rescue those rather than the stdlib classes it used to see.
  test "default fetch raises FetchError for transport failures" do
    assert_fetch_error { raise Faraday::TimeoutError, "read timeout" }
    assert_fetch_error { raise Faraday::ConnectionFailed, "connection refused" }
  end

  test "default fetch returns parsed JWKS on success" do
    stubs = stub_apple_jwks { [200, {}, '{"keys":[{"kid":"apple","kty":"RSA"}]}'] }

    stub_outbound_http(stubs) do
      jwks = ExternalAuthentication::AppleNotificationJwksCache.new.loader.call({})

      assert_equal([{ "kid" => "apple", "kty" => "RSA" }], jwks["keys"])
    end

    stubs.verify_stubbed_calls
  end

  private

  def stub_apple_jwks(&)
    Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get(ExternalAuthentication::AppleNotificationJwksCache::JWKS_URI.to_s, &)
    end
  end

  def assert_fetch_error(&)
    stubs = stub_apple_jwks(&)

    stub_outbound_http(stubs) do
      assert_raises(ExternalAuthentication::AppleNotificationJwksCache::FetchError) do
        ExternalAuthentication::AppleNotificationJwksCache.new.loader.call({})
      end
    end

    stubs.verify_stubbed_calls
  end
end
