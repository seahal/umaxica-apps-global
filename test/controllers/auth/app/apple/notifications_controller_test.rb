# frozen_string_literal: true

require "test_helper"

class Auth::App::Apple::NotificationsControllerTest < ActionDispatch::IntegrationTest
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  setup do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
  end

  test "accepts a bounded JSON notification without a browser CSRF token" do
    result = ExternalAuthenticationAppleNotificationIngress::Result.new(status: :accepted, event: nil)

    ExternalAuthenticationAppleNotificationIngress.stub(:call, ->(**) { result }) do
      post auth_app_apple_notifications_path,
           params: { payload: "signed-payload" }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
    end

    assert_response :ok
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "rejects an oversized body before invoking notification ingress" do
    called = false

    ExternalAuthenticationAppleNotificationIngress.stub(:call, ->(**) { called = true }) do
      post auth_app_apple_notifications_path,
           params: "",
           headers: {
             "CONTENT_TYPE" => "application/json",
             "CONTENT_LENGTH" => (Auth::App::Apple::NotificationsController::MAXIMUM_BODY_BYTES + 1).to_s,
           }
    end

    assert_response :payload_too_large
    assert_not called
  end

  test "rejects an invalid signature without creating an inbox event" do
    error = ExternalAuthentication::AppleNotificationVerifier::VerificationError.new(:signature_or_claims_invalid)

    ExternalAuthenticationAppleNotificationIngress.stub(:call, ->(**) { raise error }) do
      post auth_app_apple_notifications_path,
           params: { payload: "invalid" }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
    end

    assert_response :unauthorized
    assert_equal 0, ClientAppleNotificationEvent.count
  end

  test "reports verifier configuration failure as unavailable" do
    error = ExternalAuthentication::AppleNotificationVerifier::ConfigurationError.new("configuration invalid")

    ExternalAuthenticationAppleNotificationIngress.stub(:call, ->(**) { raise error }) do
      post auth_app_apple_notifications_path,
           params: { payload: "signed" }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
    end

    assert_response :service_unavailable
  end

  test "rejects malformed JSON without invoking notification ingress" do
    called = false

    ExternalAuthenticationAppleNotificationIngress.stub(:call, ->(**) { called = true }) do
      post auth_app_apple_notifications_path,
           params: "{",
           headers: { "CONTENT_TYPE" => "application/json" }
    end

    assert_response :bad_request
    assert_not called
  end

  test "rate limits notification requests by source IP" do
    original_store = Rails.configuration.x.rate_limit.fetch(:store)
    Rails.configuration.x.rate_limit.store = ActiveSupport::Cache::MemoryStore.new
    result = ExternalAuthenticationAppleNotificationIngress::Result.new(status: :accepted, event: nil)

    ExternalAuthenticationAppleNotificationIngress.stub(:call, ->(**) { result }) do
      60.times do
        post(
          auth_app_apple_notifications_path,
          params: { payload: "signed-payload" }.to_json,
          headers: { "CONTENT_TYPE" => "application/json", "REMOTE_ADDR" => "198.51.100.42" },
        )

        assert_response :ok
      end

      post(
        auth_app_apple_notifications_path,
        params: { payload: "signed-payload" }.to_json,
        headers: { "CONTENT_TYPE" => "application/json", "REMOTE_ADDR" => "198.51.100.42" },
      )
    end

    assert_response :too_many_requests
  ensure
    Rails.configuration.x.rate_limit.store = original_store if original_store
  end
end
