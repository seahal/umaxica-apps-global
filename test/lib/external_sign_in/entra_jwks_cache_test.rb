# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalSignIn::EntraJwksCacheTest < ActiveSupport::TestCase
  TENANT_ID = "11111111-2222-3333-4444-555555555555"

  test "returns and caches a valid JWKS document" do
    cache = ActiveSupport::Cache::MemoryStore.new
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.body = JSON.generate("keys" => [{ "kid" => "key-1" }])
    requests = 0

    Rails.stub(:cache, cache) do
      Net::HTTP.stub(:get_response, ->(*) { requests += 1; response }) do
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

    Rails.stub(:cache, cache) do
      Net::HTTP.stub(
        :get_response, ->(*) {
          requests += 1
          response = Net::HTTPOK.new("1.1", "200", "OK")
          response.instance_variable_set(:@read, true)
          response.body = JSON.generate("keys" => [{ "kid" => "key-#{requests}" }])
          response
        },
      ) do
        loader = ExternalSignIn::EntraJwksCache.new(tenant_id: TENANT_ID).loader

        assert_equal "key-1", loader.call({}).fetch("keys").first.fetch("kid")
        assert_equal "key-2", loader.call(kid_not_found: true).fetch("keys").first.fetch("kid")
      end
    end

    assert_equal 2, requests
  end

  test "raises FetchError for a non-success HTTP response" do
    response = Net::HTTPBadGateway.new("1.1", "502", "Bad Gateway")
    response.instance_variable_set(:@read, true)
    response.body = "upstream unavailable"

    Net::HTTP.stub(:get_response, response) do
      assert_raises(ExternalSignIn::EntraJwksCache::FetchError) do
        ExternalSignIn::EntraJwksCache.new(tenant_id: TENANT_ID).loader.call({})
      end
    end
  end

  test "raises FetchError for invalid JSON and invalid JWKS shape" do
    invalid_json = Net::HTTPOK.new("1.1", "200", "OK")
    invalid_json.instance_variable_set(:@read, true)
    invalid_json.body = "not-json"

    Net::HTTP.stub(:get_response, invalid_json) do
      assert_raises(ExternalSignIn::EntraJwksCache::FetchError) do
        ExternalSignIn::EntraJwksCache.new(tenant_id: TENANT_ID).loader.call({})
      end
    end

    invalid_shape = Net::HTTPOK.new("1.1", "200", "OK")
    invalid_shape.instance_variable_set(:@read, true)
    invalid_shape.body = JSON.generate("keys" => "not-an-array")

    Net::HTTP.stub(:get_response, invalid_shape) do
      assert_raises(ExternalSignIn::EntraJwksCache::FetchError) do
        ExternalSignIn::EntraJwksCache.new(tenant_id: TENANT_ID).loader.call({})
      end
    end
  end

  test "raises FetchError when the JWKS response body is missing" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.body = nil

    Net::HTTP.stub(:get_response, response) do
      assert_raises(ExternalSignIn::EntraJwksCache::FetchError) do
        ExternalSignIn::EntraJwksCache.new(tenant_id: TENANT_ID).loader.call({})
      end
    end
  end

  test "raises FetchError for transport failures" do
    Net::HTTP.stub(:get_response, ->(*) { raise Net::ReadTimeout }) do
      assert_raises(ExternalSignIn::EntraJwksCache::FetchError) do
        ExternalSignIn::EntraJwksCache.new(tenant_id: TENANT_ID).loader.call({})
      end
    end
  end
end
