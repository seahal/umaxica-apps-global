# typed: false
# frozen_string_literal: true

require "test_helper"

class AcmeOauthTokenRateLimitTest < ActionDispatch::IntegrationTest
  TokenResult =
    Struct.new(:success, :error, :error_description, keyword_init: true) do
      def success?
        success
      end
    end

  setup do
    clear_rate_limit_store

    assert_instance_of ActiveSupport::Cache::MemoryStore, rate_limit_store
  end

  teardown do
    clear_rate_limit_store
  end

  test "acme app oauth token endpoint rate limits repeated requests" do
    assert_token_endpoint_rate_limit(
      host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
      url_helper: ->(host:) { acme_app_oauth_token_url(host: host) },
      rule_name: "acme_app_oauth_token_exchange_ip",
    )
  end

  test "acme com oauth token endpoint rate limits repeated requests" do
    assert_token_endpoint_rate_limit(
      host: ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"),
      url_helper: ->(host:) { acme_com_oauth_token_url(host: host) },
      rule_name: "acme_com_oauth_token_exchange_ip",
    )
  end

  test "acme org oauth token endpoint rate limits repeated requests" do
    assert_token_endpoint_rate_limit(
      host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"),
      url_helper: ->(host:) { acme_org_oauth_token_url(host: host) },
      rule_name: "acme_org_oauth_token_exchange_ip",
    )
  end

  private

  def assert_token_endpoint_rate_limit(host:, url_helper:, rule_name:)
    remote_ip = "198.51.100.42"
    result = TokenResult.new(
      success: false,
      error: "invalid_grant",
      error_description: "invalid_code",
    )

    OidcTokenExchangeCoordinator.stub(:call, ->(**) { result }) do
      10.times do
        post(
          url_helper.call(host: host),
          params: invalid_token_params,
          as: :json,
          headers: { "REMOTE_ADDR" => remote_ip },
        )

        assert_not_equal 429, response.status
      end

      post(
        url_helper.call(host: host),
        params: invalid_token_params,
        as: :json,
        headers: { "REMOTE_ADDR" => remote_ip },
      )

      assert_response :too_many_requests
      assert_equal "rails", response.headers["X-RateLimit-Layer"]
      assert_equal rule_name, response.headers["X-RateLimit-Rule"]
      assert_equal "60", response.headers["Retry-After"]
      assert_equal "rate_limited", response.parsed_body["error"]
      assert_equal rule_name, response.parsed_body["rule"]
      assert_equal I18n.t("errors.rate_limit.exceeded"), response.parsed_body["message"]
    end
  end

  def invalid_token_params
    {
      grant_type: "authorization_code",
      code: "invalid-code",
      redirect_uri: "https://client.example/callback",
      client_id: "invalid-client",
      client_secret: "invalid-secret",
      code_verifier: "invalid-verifier",
    }
  end

  def rate_limit_store
    Rails.configuration.x.rate_limit.fetch(:store)
  end

  def clear_rate_limit_store
    rate_limit_store.clear
  end
end
