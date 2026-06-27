# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Sign::In::EmailsControllerExtraTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    ActionMailer::Base.deliveries.clear
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }

    ensure_visitor_reference_records!
    # Client status might be different from Visitor status
    ClientStatus.find_or_create_by!(id: 1)
  end

  test "post create with Turnstile failure" do
    CloudflareTurnstile.test_validation_response = { "success" => false }

    post auth_app_sign_in_email_url,
         params: {
           user_email: { address: "test@example.com" },
           "cf-turnstile-response": "fail",
         },
         headers: { "Host" => @host }

    assert_response :unprocessable_content
  end

  test "post create executes server-side visible Turnstile verification" do
    calls = []
    verifier =
      lambda do |token:, remote_ip:, mode:, **|
        calls << { token: token, remote_ip: remote_ip, mode: mode }
        { "success" => false }
      end

    CloudflareTurnstile.test_mode = false
    JitSecurityTurnstileVerifier.stub(:verify, verifier) do
      post(
        auth_app_sign_in_email_url,
        params: {
          user_email: { address: "turnstile-signin-#{SecureRandom.hex(4)}@example.com" },
          "cf-turnstile-response": "signin-token",
        },
        headers: { "Host" => @host },
      )
    end

    assert_response :unprocessable_content
    assert_equal [{ token: "signin-token", remote_ip: "127.0.0.1", mode: :visible }], calls
  ensure
    CloudflareTurnstile.test_mode = true
  end

  test "post create with email cooldown active" do
    address = "cooldown@example.com"

    post auth_app_sign_in_email_url,
         params: { user_email: { address: address }, "cf-turnstile-response": "test" },
         headers: { "Host" => @host }

    assert_response :redirect

    post auth_app_sign_in_email_url,
         params: { user_email: { address: address }, "cf-turnstile-response": "test" },
         headers: { "Host" => @host }

    assert_response :too_many_requests
  end

  test "patch update success with JSON" do
    user = Client.create!(status_id: 1)
    email = ClientEmail.create!(
      user: user,
      address: "app-json-success@example.com",
      user_email_status_id: 1,
      confirm_policy: "1",
    )

    post auth_app_sign_in_email_url,
         params: { user_email: { address: email.address }, "cf-turnstile-response": "test" },
         headers: { "Host" => @host }

    email.reload
    otp_code = ROTP::HOTP.new(email.otp_private_key).at(email.otp_counter.to_i)

    patch auth_app_sign_in_email_url(format: :json),
          params: { user_email: { pass_code: otp_code } },
          headers: { "Host" => @host }

    assert_response :ok
    json = response.parsed_body

    assert json.key?("access_token") || json.key?("tokens")
  end

  test "patch update failure with JSON" do
    user = Client.create!(status_id: 1)
    email = ClientEmail.create!(
      user: user,
      address: "app-json-fail@example.com",
      user_email_status_id: 1,
      confirm_policy: "1",
    )

    post auth_app_sign_in_email_url,
         params: { user_email: { address: email.address }, "cf-turnstile-response": "test" },
         headers: { "Host" => @host }

    patch auth_app_sign_in_email_url(format: :json),
          params: { user_email: { pass_code: "000000" } },
          headers: { "Host" => @host }

    assert_response :unprocessable_content
    json = response.parsed_body

    assert json.key?("error")
  end

  test "patch update with dummy OTP" do
    # Unknown email
    post auth_app_sign_in_email_url,
         params: { user_email: { address: "unknown@example.com" }, "cf-turnstile-response": "test" },
         headers: { "Host" => @host }

    # We need to make the dummy ClientEmail valid.
    # But ClientEmail requires a user.
    # The controller does ClientEmail.new(address: ...) which is invalid.
    # So it will render :edit with errors.

    patch auth_app_sign_in_email_url,
          params: { user_email: { pass_code: "123456" } },
          headers: { "Host" => @host }

    assert_response :unprocessable_content
    assert_includes response.body, "Userを入力してください"
  end
end
