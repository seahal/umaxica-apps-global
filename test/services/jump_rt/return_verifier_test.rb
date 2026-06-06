# frozen_string_literal: true

require "test_helper"

class JumpRtReturnVerifierTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @private_key = OpenSSL::PKey::EC.generate("secp384r1")
    @public_jwk = JWT::JWK.new(@private_key, kid: "jump-test").export.stringify_keys.except("d").merge(
      "alg" => "ES384",
      "use" => "sig",
    )
    @now = Time.current.change(usec: 0)
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @previous_cache
  end

  test "verifies jump-signed return token against configured jwks" do
    token = sign_return_token

    result = verify(token)

    assert_predicate result, :success?
    assert_equal "https://jump.umaxica.net", result.payload.fetch("iss")
    assert_equal "https://id.umaxica.app", result.payload.fetch("src")
  end

  test "allows reusable return token jti by default" do
    token = sign_return_token(jti: "reusable-jti")

    assert_predicate verify(token), :success?
    assert_predicate verify(token), :success?
  end

  test "rejects replayed return token jti when replay policy is one-time" do
    token = sign_return_token(jti: "single-use-jti", rpl: "once")

    assert_predicate verify(token), :success?
    assert_equal "replayed", verify(token).error
  end

  test "one-time jti cache expires no later than token expiration plus leeway" do
    token = sign_return_token(jti: "ttl-jti", rpl: "once", exp: @now.to_i + 10)

    assert_predicate verify(token), :success?

    key = "jump_rt:return_jti:#{Digest::SHA256.hexdigest("https://jump.umaxica.net:ttl-jti")}"

    assert Rails.cache.exist?(key)

    travel_to(@now + JumpRtReturnVerifier::LEEWAY + 11.seconds) do
      assert_not Rails.cache.exist?(key)
    end
  end

  test "rejects unknown replay policy" do
    token = sign_return_token(rpl: "single")

    assert_equal "invalid_claim", verify(token).error
  end

  test "rejects wrong audience" do
    token = sign_return_token(aud: "https://www.umaxica.com")

    assert_equal "invalid_signature", verify(token).error
  end

  test "rejects wrong source for destination origin" do
    token = sign_return_token(src: "https://id.umaxica.com")

    assert_equal "invalid_claim", verify(token).error
  end

  test "rejects when token url does not match current request without rt" do
    token = sign_return_token(url: "https://www.umaxica.app/other")

    assert_equal "invalid_url", verify(token).error
  end

  test "matches token url to request when query parameter order differs" do
    token = sign_return_token(url: "https://www.umaxica.app/path?ok=1&extra=2")

    result = JumpRtReturnVerifier.call(
      token: token,
      request_url: "https://www.umaxica.app/path?extra=2&rt=#{token}&ok=1",
      request_base_url: "https://www.umaxica.app",
      fetcher: -> { { "keys" => [@public_jwk] } },
      now: @now,
    )

    assert_predicate result, :success?
  end

  test "rejects jwks entries with private material" do
    token = sign_return_token
    jwks = { "keys" => [@public_jwk.merge("d" => "private")] }

    result = JumpRtReturnVerifier.call(
      token: token,
      request_url: "https://www.umaxica.app/path?ok=1&rt=#{token}",
      request_base_url: "https://www.umaxica.app",
      fetcher: -> { jwks },
      now: @now,
    )

    assert_equal "invalid_signature", result.error
  end

  test "rejects excessive ttl" do
    token = sign_return_token(exp: @now.to_i + 1.hour.to_i)

    assert_equal "invalid_claim", verify(token).error
  end

  test "refreshes jwks once when kid is missing from cached set" do
    token = sign_return_token
    calls = 0
    fetcher =
      lambda do
        calls += 1
        { "keys" => (calls == 1) ? [] : [@public_jwk] }
      end

    result = JumpRtReturnVerifier.call(
      token: token,
      request_url: "https://www.umaxica.app/path?ok=1&rt=#{token}",
      request_base_url: "https://www.umaxica.app",
      fetcher: fetcher,
      now: @now,
    )

    assert_predicate result, :success?
    assert_equal 2, calls
  end

  test "negative caches unknown kid after forced refresh misses" do
    token = sign_return_token
    calls = 0
    fetcher =
      lambda do
        calls += 1
        { "keys" => [] }
      end

    2.times do
      result = JumpRtReturnVerifier.call(
        token: token,
        request_url: "https://www.umaxica.app/path?ok=1&rt=#{token}",
        request_base_url: "https://www.umaxica.app",
        fetcher: fetcher,
        now: @now,
      )

      assert_equal "invalid_signature", result.error
    end

    assert_equal 2, calls
  end

  test "rejects locally revoked kid before using cached jwks" do
    token = sign_return_token

    with_env("JUMP_RETURN_REVOKED_KIDS" => "jump-test") do
      result = verify(token)

      assert_equal "revoked_kid", result.error
    end
  end

  test "requires https jwks url" do
    token = sign_return_token

    with_env("JUMP_GATEWAY_JWKS_URL" => "http://jump.umaxica.net/.well-known/jwks.json") do
      result = JumpRtReturnVerifier.call(
        token: token,
        request_url: "https://www.umaxica.app/path?ok=1&rt=#{token}",
        request_base_url: "https://www.umaxica.app",
        now: @now,
      )

      assert_equal "invalid_signature", result.error
    end
  end

  test "uses stale cached jwks when refresh fails" do
    token = sign_return_token
    jwks_url = "https://jump.umaxica.net/.well-known/jwks.json"
    stale_key = "jump_rt:return_jwks:stale:#{Digest::SHA256.hexdigest(jwks_url)}"
    Rails.cache.write(stale_key, { "keys" => [@public_jwk] }, expires_in: 1.hour)

    result = JumpRtReturnVerifier.call(
      token: token,
      request_url: "https://www.umaxica.app/path?ok=1&rt=#{token}",
      request_base_url: "https://www.umaxica.app",
      fetcher: -> { raise JWT::DecodeError, "offline" },
      now: @now,
    )

    assert_predicate result, :success?
  end

  private

  def verify(token)
    JumpRtReturnVerifier.call(
      token: token,
      request_url: "https://www.umaxica.app/path?ok=1&rt=#{token}",
      request_base_url: "https://www.umaxica.app",
      fetcher: -> { { "keys" => [@public_jwk] } },
      now: @now,
    )
  end

  def sign_return_token(overrides = {})
    iat = @now.to_i
    payload = {
      schema: 1,
      iss: "https://jump.umaxica.net",
      aud: "https://www.umaxica.app",
      sub: "jump-redirect",
      iat: iat,
      nbf: iat,
      exp: iat + 60,
      jti: "jump-return-jti",
      src: "https://id.umaxica.app",
      dst: "internal",
      url: "https://www.umaxica.app/path?ok=1",
    }.merge(overrides)

    JWT.encode(payload, @private_key, "ES384", { typ: "JWT", kid: "jump-test" })
  end

  def with_env(values)
    previous = {}
    values.each do |key, value|
      previous[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
