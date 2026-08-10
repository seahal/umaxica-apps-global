# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OmniauthTest < ActiveSupport::TestCase
  test "omniauth request phase uses social path prefix" do
    assert_equal "/social", OmniAuth.config.path_prefix
  end

  test "callback origin uses https for configured app sign host" do
    env = Rack::MockRequest.env_for(
      "http://log.umaxica.app/social/google/callback",
      "HTTP_HOST" => "log.umaxica.app",
    )

    OmniAuthCallbackOrigin.stub(:public_sign_hosts, ["log.umaxica.app"]) do
      assert_equal "https://log.umaxica.app", OmniAuthCallbackOrigin.call(env)
    end
  end

  test "callback origin uses https for configured org sign host" do
    env = Rack::MockRequest.env_for(
      "http://log.umaxica.org/social/failure",
      "HTTP_HOST" => "log.umaxica.org",
    )

    OmniAuthCallbackOrigin.stub(:public_sign_hosts, ["log.umaxica.org"]) do
      assert_equal "https://log.umaxica.org", OmniAuthCallbackOrigin.call(env)
    end
  end

  test "callback origin preserves request scheme for unconfigured hosts" do
    env = Rack::MockRequest.env_for(
      "http://id.app.localhost/social/google/callback",
      "HTTP_HOST" => "id.app.localhost",
    )

    OmniAuthCallbackOrigin.stub(:public_sign_hosts, []) do
      assert_equal "http://id.app.localhost", OmniAuthCallbackOrigin.call(env)
    end
  end

  test "apple failure logs nonce context without raw nonce values" do
    env = Rack::MockRequest.env_for("/social/failure?message=invalid_credentials&strategy=apple")
    env["omniauth.error.type"] = "invalid_credentials"
    env["omniauth.error.strategy"] = Struct.new(:name).new("apple")
    env["omniauth.error"] = StandardError.new("id_token_claims_invalid | nonce invalid")
    env["rack.session"] = {
      "omniauth.nonce" => "strategy-nonce",
      :social_auth_nonce => "app-nonce",
    }

    logged = []
    logger = Struct.new(:logged) do
      def error(*)
      end

      def info(message = nil)
        logged << JSON.parse(message, symbolize_names: true) if message.to_s.start_with?("{")
      end
    end.new(logged)

    Rails.stub(:logger, logger) do
      OmniAuth.config.on_failure.call(env)
    end

    event = logged.find { |entry| entry[:event] == "social_auth.apple.nonce_failure_context" }

    assert_not_nil event
    assert_equal "/social/failure", event.dig(:data, :request_path)
    assert_equal "GET", event.dig(:data, :request_method)
    assert event.dig(:data, :strategy_has_value)
    assert event.dig(:data, :app_has_value)
    assert_not_includes logged.to_s, "strategy-nonce"
    assert_not_includes logged.to_s, "app-nonce"
  end

  test "omniauth failure logs normalized metadata without the provider exception message" do
    env = Rack::MockRequest.env_for("/social/failure?message=invalid_credentials&strategy=google")
    env["omniauth.error.type"] = "invalid_credentials"
    env["omniauth.error.strategy"] = Struct.new(:name).new("google")
    provider_secret = "audit-provider-response-token-not-a-real-secret"
    env["omniauth.error"] = StandardError.new("provider response contained #{provider_secret}")

    errors = []
    logger = Struct.new(:errors) do
      def error(message)
        errors << message
      end

      def info(*)
      end
    end.new(errors)

    Rails.stub(:logger, logger) do
      OmniAuth.config.on_failure.call(env)
    end

    event = errors.map { |message| JSON.parse(message) }.find { |entry| entry["event"] == "social_auth.failure" }

    assert_not_nil event
    assert_equal "google", event.dig("data", "strategy")
    assert_equal "invalid_credentials", event.dig("data", "type")
    assert_equal "StandardError", event.dig("data", "error_class")
    assert_not_includes errors.join("\n"), provider_secret
  end
end
