# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthAuthenticationRateLimitTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  teardown do
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  test "app secret credential sign-in hits explicit rails rate limit" do
    host! ENV.fetch("AUTH_SERVICE_URL", "auth.app.localhost")

    5.times do
      post auth_app_sign_in_secret_credential_url(ri: "jp"),
           params: { secret_credential_login_form: { identifier: "", secret_credential_value: "" } }
    end

    post auth_app_sign_in_secret_credential_url(ri: "jp"),
         params: { secret_credential_login_form: { identifier: "", secret_credential_value: "" } }

    assert_sign_rate_limited("auth_app_sign_in_secret_credential_create_ip_burst")
  end

  test "com secret credential sign-in hits explicit rails rate limit" do
    host! ENV.fetch("AUTH_CORPORATE_URL", "auth.com.localhost")

    5.times do
      post auth_com_sign_in_secret_credential_url(ri: "jp"),
           params: { secret_credential_login_form: { identifier: "", secret_credential_value: "" } }
    end

    post auth_com_sign_in_secret_credential_url(ri: "jp"),
         params: { secret_credential_login_form: { identifier: "", secret_credential_value: "" } }

    assert_sign_rate_limited("auth_com_sign_in_secret_credential_create_ip_burst")
  end

  test "org secret credential sign-in hits explicit rails rate limit" do
    host! ENV.fetch("AUTH_STAFF_URL", "auth.org.localhost")

    5.times do
      post auth_org_sign_in_secret_credential_url(ri: "jp"),
           params: { secret_credential_login_form: { identifier: "", secret_credential_value: "" } }
    end

    post auth_org_sign_in_secret_credential_url(ri: "jp"),
         params: { secret_credential_login_form: { identifier: "", secret_credential_value: "" } }

    assert_sign_rate_limited("auth_org_sign_in_secret_credential_create_ip_burst")
  end

  test "app passkey options sign-in hits explicit rails rate limit" do
    host!(ENV.fetch("AUTH_SERVICE_URL", "auth.app.localhost"))
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }

    5.times do
      post(auth_app_sign_in_passkey_options_url(ri: "jp"), params: { identifier: "" }, as: :json)
    end

    post(auth_app_sign_in_passkey_options_url(ri: "jp"), params: { identifier: "" }, as: :json)

    assert_sign_rate_limited("auth_app_sign_in_passkey_options_ip_burst")
  ensure
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  private

  def assert_sign_rate_limited(rule_name)
    assert_response :too_many_requests
    assert_equal "rails", response.headers["X-RateLimit-Layer"]
    assert_equal rule_name, response.headers["X-RateLimit-Rule"]
    assert_equal "60", response.headers["Retry-After"]

    if response.media_type == "application/json"
      body = response.parsed_body

      assert_equal "rate_limited", body["error"]
      assert_equal rule_name, body["rule"]
      assert_equal I18n.t("errors.rate_limit.exceeded"), body["message"]
    else
      assert_equal "text/plain", response.media_type
      assert_equal I18n.t("errors.rate_limit.exceeded"), response.body
    end
  end
end
