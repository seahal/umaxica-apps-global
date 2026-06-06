# frozen_string_literal: true

require "test_helper"

class JumpRtReturnVerificationTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @jump_private_key = OpenSSL::PKey::EC.generate("secp384r1")
    @jump_public_jwk = JWT::JWK.new(@jump_private_key, kid: "jump-test").export.stringify_keys.except("d").merge(
      "alg" => "ES384",
      "use" => "sig",
    )
    @rails_private_key = OpenSSL::PKey::EC.generate("secp384r1")
    @rails_public_jwk = JWT::JWK.new(@rails_private_key, kid: "acme-app-test").export.stringify_keys.except("d").merge(
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

  test "rails issued rt can round trip through a stubbed jump gateway and return verifier" do
    with_env(
      "ACME_SERVICE_URL" => "www.app.localhost",
      "ID_SERVICE_URL" => "www.umaxica.app",
      "JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
    ) do
      JumpRt::Keyring.stub(:active_kid, "acme-app-test") do
        JumpRt::Keyring.stub(:private_key, @rails_private_key) do
          rails_rt = JumpRt::Issuer.call(
            namespace: "ACME_APP",
            url: "https://www.app.localhost/",
            dst: "internal",
            now: @now,
            jti: "rails-jti",
          )

          returned_location = stubbed_jump_location(rails_rt)
          returned_rt = Rack::Utils.parse_nested_query(URI.parse(returned_location).query).fetch("rt")
          prime_jump_jwks_cache

          host! "www.app.localhost"
          https!
          get "/", params: { rt: returned_rt }
        end
      end
    end

    assert_response :see_other
    assert_equal "https://www.app.localhost/", response.location
    assert_match(/no-store/, response.headers.fetch("Cache-Control"))
  end

  test "acme app consumes valid jump return rt and strips it from url" do
    host! "www.app.localhost"
    https!
    token = sign_return_token(
      aud: "https://www.app.localhost",
      src: "https://id.app.localhost",
      url: "https://www.app.localhost/?ok=1",
    )

    JumpRt::ReturnVerifier.stub(:call, verifier_success) do
      get "/", params: { ok: "1", rt: token }
    end

    assert_response :see_other
    assert_equal "https://www.app.localhost/?ok=1", response.location
  end

  test "acme app rejects invalid jump return rt before normal auth flow" do
    host! "www.app.localhost"
    https!

    get "/", params: { rt: "not-a-jwt" }

    assert_response :bad_request
  end

  test "sign surface does not include jump return verification" do
    assert_not_includes Sign::App::ApplicationController.ancestors, JumpRt::ReturnVerification
    assert_not_includes Sign::Com::ApplicationController.ancestors, JumpRt::ReturnVerification
    assert_not_includes Sign::Org::ApplicationController.ancestors, JumpRt::ReturnVerification
  end

  test "return verification concern does not register callbacks when included" do
    controller =
      Class.new(ActionController::Base) do # rubocop:disable Rails/ApplicationController
        include JumpRt::ReturnVerification
      end

    before_filters =
      controller._process_action_callbacks.filter_map do |callback|
        callback.filter if callback.kind == :before
      end

    assert_not_includes before_filters, :verify_jump_return_rt!
  end

  test "core app explicitly runs jump return verification before normal auth flow" do
    before_filters =
      Core::App::ApplicationController._process_action_callbacks.filter_map do |callback|
        callback.filter if callback.kind == :before
      end

    assert_includes before_filters, :verify_jump_return_rt!
    assert_operator before_filters.index(:verify_jump_return_rt!), :<, before_filters.index(:set_current_context)
  end

  private

  def verifier_success
    lambda do |token:, request_url:, request_base_url:|
      assert_predicate token, :present?
      assert_equal "https://www.app.localhost/?ok=1&rt=#{token}", request_url
      assert_equal "https://www.app.localhost", request_base_url

      JumpRt::ReturnVerifier::Result.new(success: true, payload: {}, error: nil)
    end
  end

  def stubbed_jump_location(rails_rt)
    rails_issuer = JumpRt::Surface.issuer_origin("ACME_APP")
    payload, header = JWT.decode(
      rails_rt,
      JWT::JWK.import(@rails_public_jwk).public_key,
      true,
      algorithms: ["ES384"],
      iss: rails_issuer,
      verify_iss: true,
      aud: "https://jump.umaxica.net",
      verify_aud: true,
      verify_iat: false,
      verify_expiration: false,
      verify_not_before: false,
    )

    assert_equal "JWT", header.fetch("typ")
    assert_equal "acme-app-test", header.fetch("kid")
    assert_equal rails_issuer, payload.fetch("iss")
    assert_equal 1, payload.fetch("schema")
    assert_equal "jump-redirect", payload.fetch("sub")
    assert_equal "internal", payload.fetch("dst")
    assert_equal "https://www.app.localhost/", payload.fetch("url")

    return_rt = sign_return_token(
      aud: "https://www.app.localhost",
      src: payload.fetch("iss"),
      url: payload.fetch("url"),
      jti: "jump-jti",
      iat: @now.to_i,
      nbf: @now.to_i,
      exp: @now.to_i + 60,
    )
    "https://www.app.localhost/?#{Rack::Utils.build_query(rt: return_rt)}"
  end

  def prime_jump_jwks_cache
    jwks_url = "https://jump.umaxica.net/.well-known/jwks.json"
    cache_key = "jump_rt:return_jwks:#{Digest::SHA256.hexdigest(jwks_url)}"
    Rails.cache.write(cache_key, { "keys" => [@jump_public_jwk] }, expires_in: 5.minutes)
  end

  def sign_return_token(overrides = {})
    iat = @now.to_i
    payload = {
      schema: 1,
      iss: "https://jump.umaxica.net",
      aud: "https://www.app.localhost",
      sub: "jump-redirect",
      iat: iat,
      nbf: iat,
      exp: iat + 60,
      jti: "jump-return-jti",
      src: "https://id.app.localhost",
      dst: "internal",
      url: "https://www.app.localhost/",
    }.merge(overrides)

    JWT.encode(payload, @jump_private_key, "ES384", { typ: "JWT", kid: "jump-test" })
  end

  def with_env(values)
    previous = values.transform_values { |_value| nil }
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
