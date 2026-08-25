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
    response = Net::HTTPBadRequest.new("1.1", "400", "Bad Request")
    response.instance_variable_set(:@read, true)
    response.body = "nope"

    http = Object.new
    http.define_singleton_method(:request) { |_req| response }

    Net::HTTP.stub(:start, ->(*_args, **_kwargs, &block) { block.call(http) }) do
      error =
        assert_raises(ExternalAuthentication::AppleNotificationJwksCache::FetchError) do
          ExternalAuthentication::AppleNotificationJwksCache.new.send(:fetch_jwks)
        end

      assert_instance_of ExternalAuthentication::AppleNotificationJwksCache::FetchError, error
    end
  end

  test "default fetch raises FetchError for oversized or invalid JSON bodies" do
    oversized = Net::HTTPOK.new("1.1", "200", "OK")
    oversized.instance_variable_set(:@read, true)
    oversized.body = "x" * (ExternalAuthentication::AppleNotificationJwksCache::MAXIMUM_RESPONSE_BYTES + 1)

    invalid = Net::HTTPOK.new("1.1", "200", "OK")
    invalid.instance_variable_set(:@read, true)
    invalid.body = "not-json"

    missing_keys = Net::HTTPOK.new("1.1", "200", "OK")
    missing_keys.instance_variable_set(:@read, true)
    missing_keys.body = '{"hello":[]}'

    http = Object.new
    bodies = [oversized, invalid, missing_keys]
    http.define_singleton_method(:request) { |_req| bodies.shift }

    Net::HTTP.stub(:start, ->(*_args, **_kwargs, &block) { block.call(http) }) do
      cache = ExternalAuthentication::AppleNotificationJwksCache.new

      3.times do
        assert_raises(ExternalAuthentication::AppleNotificationJwksCache::FetchError) do
          cache.send(:fetch_jwks)
        end
      end
    end
  end

  test "default fetch returns parsed JWKS on success" do
    ok = Net::HTTPOK.new("1.1", "200", "OK")
    ok.instance_variable_set(:@read, true)
    ok.body = '{"keys":[{"kid":"apple","kty":"RSA"}]}'

    http = Object.new
    http.define_singleton_method(:request) { |_req| ok }

    Net::HTTP.stub(:start, ->(*_args, **_kwargs, &block) { block.call(http) }) do
      jwks = ExternalAuthentication::AppleNotificationJwksCache.new.send(:fetch_jwks)

      assert_equal([{ "kid" => "apple", "kty" => "RSA" }], jwks["keys"])
    end
  end
end
