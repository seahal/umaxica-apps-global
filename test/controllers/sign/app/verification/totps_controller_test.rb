# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::App::Verification::TotpsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :user_one_time_password_statuses

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = User.create!(status_id: UserStatus::NOTHING)
    @headers = as_user_headers(@user, host: @host)
    @token = UserToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  def with_prosopite_paused
    Prosopite.pause { yield }
  end

  test "creates verification on success" do
    private_key = "JBSWY3DPEHPK3PXP"
    UserOneTimePassword.create!(
      user: @user,
      private_key: private_key,
      user_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    return_to = Base64.urlsafe_encode64(sign_app_configuration_emails_path(ri: "jp"))
    with_prosopite_paused do
      get sign_app_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
          headers: @headers
    end

    assert_response :success

    with_prosopite_paused do
      get new_sign_app_verification_totp_url(ri: "jp"), headers: @headers
    end

    assert_response :success
    assert_select "input[name='cf-turnstile-response']"

    session[:reauth_email_otp] = { "expires_at" => 5.minutes.from_now.to_i }

    code = ROTP::TOTP.new(private_key).at(Time.current.to_i)

    with_prosopite_paused do
      post sign_app_verification_totp_url(ri: "jp"),
           params: { verification: { code: code } },
           headers: @headers
    end

    assert_response :redirect
    assert_redirected_to sign_app_configuration_emails_url(ri: "jp")

    @token.reload

    assert_not_nil @token.last_step_up_at
    assert_equal "configuration_email", @token.last_step_up_scope
    assert_nil session[:reauth]
    assert_nil session[:reauth_email_otp]
  end

  test "renders new on failure" do
    private_key = "JBSWY3DPEHPK3PXP"
    UserOneTimePassword.create!(
      user: @user,
      private_key: private_key,
      user_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    return_to = Base64.urlsafe_encode64(sign_app_configuration_emails_path(ri: "jp"))
    with_prosopite_paused do
      get sign_app_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
          headers: @headers
    end

    assert_response :success

    with_prosopite_paused do
      post sign_app_verification_totp_url(ri: "jp"),
           params: { verification: { code: "000000" } },
           headers: @headers
    end

    assert_response :unprocessable_content
  end

  test "returns 422 on malformed code" do
    private_key = "JBSWY3DPEHPK3PXP"
    UserOneTimePassword.create!(
      user: @user,
      private_key: private_key,
      user_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    return_to = Base64.urlsafe_encode64(sign_app_configuration_emails_path(ri: "jp"))
    with_prosopite_paused do
      get sign_app_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
          headers: @headers
    end

    assert_response :success

    with_prosopite_paused do
      post sign_app_verification_totp_url(ri: "jp"),
           params: { verification: { code: "abc123" } },
           headers: @headers
    end

    assert_response :unprocessable_content
  end

  test "new keeps scope and return_to in form hidden fields" do
    private_key = "JBSWY3DPEHPK3PXP"
    UserOneTimePassword.create!(
      user: @user,
      private_key: private_key,
      user_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    return_to = Base64.urlsafe_encode64(sign_app_configuration_emails_path(ri: "jp"))
    with_prosopite_paused do
      get sign_app_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
          headers: @headers
    end

    assert_response :success

    with_prosopite_paused do
      get new_sign_app_verification_totp_url(
        ri: "jp",
        scope: "configuration_email",
        return_to: return_to,
      ), headers: @headers
    end

    assert_response :success
    assert_select "input[name='verification[scope]'][value='configuration_email']"
    assert_select "input[name='verification[return_to]'][value='#{return_to}']"
    assert_select "input[name='cf-turnstile-response']"
  end

  test "configuration_totp flow keeps return_to through method selection and returns to totps" do
    private_key = "JBSWY3DPEHPK3PXP"
    UserOneTimePassword.create!(
      user: @user,
      private_key: private_key,
      user_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    return_to = Base64.urlsafe_encode64(sign_app_configuration_totps_path(ri: "jp"))

    with_prosopite_paused do
      get sign_app_verification_url(scope: "configuration_totp", return_to: return_to, ri: "jp"),
          headers: @headers
    end

    assert_response :success
    assert_select(
      "a[href=?]",
      new_sign_app_verification_totp_path(ri: "jp", scope: "configuration_totp", rt: return_to),
    )

    with_prosopite_paused do
      get new_sign_app_verification_totp_url(
        ri: "jp",
        scope: "configuration_totp",
        rt: return_to,
      ), headers: @headers
    end

    assert_response :success
    assert_select "input[name='verification[scope]'][value='configuration_totp']"
    assert_select "input[name='verification[return_to]'][value='#{return_to}']"
    assert_select "input[name='cf-turnstile-response']"

    code = ROTP::TOTP.new(private_key).at(Time.current.to_i)
    with_prosopite_paused do
      post sign_app_verification_totp_url(ri: "jp"),
           params: { verification: { code: code, scope: "configuration_totp", return_to: return_to } },
           headers: @headers
    end

    assert_response :redirect
    assert_redirected_to sign_app_configuration_totps_url(ri: "jp")
  end

  test "POST returns 422 when turnstile stealth fails" do
    private_key = "JBSWY3DPEHPK3PXP"
    UserOneTimePassword.create!(
      user: @user,
      private_key: private_key,
      user_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    return_to = Base64.urlsafe_encode64(sign_app_configuration_emails_path(ri: "jp"))
    with_prosopite_paused do
      get sign_app_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
          headers: @headers
    end

    assert_response :success

    CloudflareTurnstile.test_validation_response = { "success" => false }

    code = ROTP::TOTP.new(private_key).at(Time.current.to_i)
    with_prosopite_paused do
      post sign_app_verification_totp_url(ri: "jp"),
           params: { verification: { code: code } },
           headers: @headers
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("turnstile_error")
  end

  test "POST returns plain error when no usable step-up methods exist" do
    StepUp::ConfiguredMethods.stub(:call, []) do
      StepUp::AvailableMethods.stub(:call, []) do
        with_prosopite_paused do
          post sign_app_verification_totp_url(ri: "jp"),
               params: { verification: { code: "123456" } },
               headers: @headers
        end
      end
    end

    assert_response :unprocessable_content
    assert_equal I18n.t("auth.step_up.register_methods_required"), response.body
  end
end
