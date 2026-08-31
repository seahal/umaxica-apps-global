# typed: false
# frozen_string_literal: true

require "test_helper"

# Per-IP burst limiters declared on the unauthenticated auth endpoints. Each
# endpoint declares its own `rate_limit(..., with: -> { render_rate_limited })`
# handler; these exercise that handler through the real routing and controller
# stack so a limiter that is declared but never wired is a failing test rather
# than silent absence of protection.
class AuthEndpointBurstRateLimitTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  BURST_ALLOWANCE = 5
  SUSTAINED_ALLOWANCE = 20

  setup do
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "app passkey options answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_app_sign_in_passkey_options_url(ri: "jp", host: host),
           params: { identifier: "burst_app@example.com" }, as: :json
    end

    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
  end

  test "app passkey verification answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_app_sign_in_passkey_verification_url(ri: "jp", host: host),
           params: { challenge_id: "missing", credential: { id: "x" } }, as: :json
    end

    assert_response :too_many_requests
  end

  test "com passkey options answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_com_sign_in_passkey_options_url(ri: "jp", host: host),
           params: { identifier: "burst_com@example.com" }, as: :json
    end

    assert_response :too_many_requests
  end

  test "com passkey verification answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_com_sign_in_passkey_verification_url(ri: "jp", host: host),
           params: { challenge_id: "missing", credential: { id: "x" } }, as: :json
    end

    assert_response :too_many_requests
  end

  test "org passkey options answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_org_sign_in_passkey_options_url(ri: "jp", host: host),
           params: { identifier: "0123456789ABCDEF" }, as: :json
    end

    assert_response :too_many_requests
  end

  test "org passkey verification answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_org_sign_in_passkey_verification_url(ri: "jp", host: host),
           params: { challenge_id: "missing", credential: { id: "x" } }, as: :json
    end

    assert_response :too_many_requests
  end

  test "app MFA passkey challenge answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_app_sign_in_challenge_passkey_url(ri: "jp", host: host),
           params: { challenge_id: "missing" }, as: :json
    end

    assert_response :too_many_requests
  end

  test "com MFA passkey challenge answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_com_sign_in_challenge_passkey_url(ri: "jp", host: host),
           params: { challenge_id: "missing" }, as: :json
    end

    assert_response :too_many_requests
  end

  test "org MFA passkey challenge answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_org_sign_in_challenge_passkey_url(ri: "jp", host: host),
           params: { challenge_id: "missing" }, as: :json
    end

    assert_response :too_many_requests
  end

  test "app MFA TOTP challenge answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_app_sign_in_challenge_totp_url(ri: "jp", host: host),
           params: { totp_challenge_form: { token: "000000" } }
    end

    assert_response :too_many_requests
  end

  test "app secret credential sign-in answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_app_sign_in_secret_url(ri: "jp", host: host),
           params: { client_secret_credential: { identifier: "burst@example.com", secret_credential_value: "x" } }
    end

    assert_response :too_many_requests
  end

  test "com secret credential sign-in answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_com_sign_in_secret_url(ri: "jp", host: host),
           params: { visitor_secret_credential: { identifier: "burst@example.com", secret_credential_value: "x" } }
    end

    assert_response :too_many_requests
  end

  test "org secret credential sign-in answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_org_sign_in_secret_url(ri: "jp", host: host),
           params: { staff_secret_credential: { identifier: "0123456789ABCDEF", secret_credential_value: "x" } }
    end

    assert_response :too_many_requests
  end

  test "app email sign-in answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_app_sign_in_email_url(ri: "jp", host: host),
           params: { user_email: { address: "burst_signin@example.com" } }
    end

    assert_response :too_many_requests
  end

  test "com email sign-in answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_com_sign_in_email_url(ri: "jp", host: host),
           params: { visitor_email: { address: "burst_signin_com@example.com" } }
    end

    assert_response :too_many_requests
  end

  test "app passkey options answers 429 with the sustained retry hint once the 15-minute allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    # Four bursts of five, each after the one-minute burst window has rolled
    # over, spend the sustained allowance without ever tripping the burst rule.
    (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
      travel((burst * 61).seconds) do
        BURST_ALLOWANCE.times do
          post auth_app_sign_in_passkey_options_url(ri: "jp", host: host),
               params: { identifier: "sustained_app@example.com" }, as: :json

          assert_response :success
        end
      end
    end

    travel((SUSTAINED_ALLOWANCE / BURST_ALLOWANCE * 61).seconds) do
      post auth_app_sign_in_passkey_options_url(ri: "jp", host: host),
           params: { identifier: "sustained_app@example.com" }, as: :json
    end

    assert_response :too_many_requests
    assert_equal "900", response.headers["Retry-After"]
  end

  test "com passkey options answers 429 with the sustained retry hint once the 15-minute allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host

    (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
      travel((burst * 61).seconds) do
        BURST_ALLOWANCE.times do
          post auth_com_sign_in_passkey_options_url(ri: "jp", host: host),
               params: { identifier: "sustained_com@example.com" }, as: :json
        end
      end
    end

    travel((SUSTAINED_ALLOWANCE / BURST_ALLOWANCE * 61).seconds) do
      post auth_com_sign_in_passkey_options_url(ri: "jp", host: host),
           params: { identifier: "sustained_com@example.com" }, as: :json
    end

    assert_response :too_many_requests
    assert_equal "900", response.headers["Retry-After"]
  end

  test "org passkey options answers 429 with the sustained retry hint once the 15-minute allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! host

    (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
      travel((burst * 61).seconds) do
        BURST_ALLOWANCE.times do
          post auth_org_sign_in_passkey_options_url(ri: "jp", host: host),
               params: { identifier: "0123456789ABCDEF" }, as: :json
        end
      end
    end

    travel((SUSTAINED_ALLOWANCE / BURST_ALLOWANCE * 61).seconds) do
      post auth_org_sign_in_passkey_options_url(ri: "jp", host: host),
           params: { identifier: "0123456789ABCDEF" }, as: :json
    end

    assert_response :too_many_requests
    assert_equal "900", response.headers["Retry-After"]
  end

  test "app passkey verification answers 429 with the sustained retry hint once the 15-minute allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
      travel((burst * 61).seconds) do
        BURST_ALLOWANCE.times do
          post auth_app_sign_in_passkey_verification_url(ri: "jp", host: host),
               params: { challenge_id: "missing", credential: { id: "x" } }, as: :json
        end
      end
    end

    travel((SUSTAINED_ALLOWANCE / BURST_ALLOWANCE * 61).seconds) do
      post auth_app_sign_in_passkey_verification_url(ri: "jp", host: host),
           params: { challenge_id: "missing", credential: { id: "x" } }, as: :json
    end

    assert_response :too_many_requests
    assert_equal "900", response.headers["Retry-After"]
  end

  test "com passkey verification answers 429 with the sustained retry hint once the 15-minute allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host

    (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
      travel((burst * 61).seconds) do
        BURST_ALLOWANCE.times do
          post auth_com_sign_in_passkey_verification_url(ri: "jp", host: host),
               params: { challenge_id: "missing", credential: { id: "x" } }, as: :json
        end
      end
    end

    travel((SUSTAINED_ALLOWANCE / BURST_ALLOWANCE * 61).seconds) do
      post auth_com_sign_in_passkey_verification_url(ri: "jp", host: host),
           params: { challenge_id: "missing", credential: { id: "x" } }, as: :json
    end

    assert_response :too_many_requests
    assert_equal "900", response.headers["Retry-After"]
  end

  test "org passkey verification answers 429 with the sustained retry hint once the 15-minute allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! host

    (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
      travel((burst * 61).seconds) do
        BURST_ALLOWANCE.times do
          post auth_org_sign_in_passkey_verification_url(ri: "jp", host: host),
               params: { challenge_id: "missing", credential: { id: "x" } }, as: :json
        end
      end
    end

    travel((SUSTAINED_ALLOWANCE / BURST_ALLOWANCE * 61).seconds) do
      post auth_org_sign_in_passkey_verification_url(ri: "jp", host: host),
           params: { challenge_id: "missing", credential: { id: "x" } }, as: :json
    end

    assert_response :too_many_requests
    assert_equal "900", response.headers["Retry-After"]
  end
end
