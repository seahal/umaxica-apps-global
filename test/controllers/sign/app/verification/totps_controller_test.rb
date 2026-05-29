# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::App::Verification::TotpsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_one_time_password_statuses

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = Client.create!(status_id: ClientStatus::NOTHING)
    @headers = as_user_headers(@user, host: @host)
    @token = ClientToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
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
    ClientOneTimePassword.create!(
      user: @user,
      private_key: private_key,
      user_one_time_password_status_id: ClientOneTimePasswordStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    pt = signed_step_up_pt(sign_app_configuration_emails_path(ri: "jp"))
    with_prosopite_paused do
      get sign_app_verification_url(scope: "configuration_email", pt: pt, ri: "jp"),
          headers: @headers
    end

    assert_response :success

    with_prosopite_paused do
      get new_sign_app_verification_totp_url(ri: "jp"), headers: @headers
    end

    assert_response :success
    assert_select "input[name='cf-turnstile-response']"

    session[:step_up_email_otp] = { "expires_at" => 5.minutes.from_now.to_i }

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
    assert_nil session[:step_up]
    assert_nil session[:step_up_email_otp]
  end

  test "renders new on failure" do
    private_key = "JBSWY3DPEHPK3PXP"
    ClientOneTimePassword.create!(
      user: @user,
      private_key: private_key,
      user_one_time_password_status_id: ClientOneTimePasswordStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    pt = signed_step_up_pt(sign_app_configuration_emails_path(ri: "jp"))
    with_prosopite_paused do
      get sign_app_verification_url(scope: "configuration_email", pt: pt, ri: "jp"),
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
    ClientOneTimePassword.create!(
      user: @user,
      private_key: private_key,
      user_one_time_password_status_id: ClientOneTimePasswordStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    pt = signed_step_up_pt(sign_app_configuration_emails_path(ri: "jp"))
    with_prosopite_paused do
      get sign_app_verification_url(scope: "configuration_email", pt: pt, ri: "jp"),
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

  test "new keeps scope and pt in form hidden fields" do
    private_key = "JBSWY3DPEHPK3PXP"
    ClientOneTimePassword.create!(
      user: @user,
      private_key: private_key,
      user_one_time_password_status_id: ClientOneTimePasswordStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    pt = signed_step_up_pt(sign_app_configuration_emails_path(ri: "jp"))
    with_prosopite_paused do
      get sign_app_verification_url(scope: "configuration_email", pt: pt, ri: "jp"),
          headers: @headers
    end

    assert_response :success

    with_prosopite_paused do
      get new_sign_app_verification_totp_url(
        ri: "jp",
        scope: "configuration_email",
        pt: pt,
      ), headers: @headers
    end

    assert_response :success
    assert_select "input[name='verification[scope]'][value='configuration_email']"
    assert_select "input[name='verification[pt]'][value='#{pt}']"
    assert_select "input[name='cf-turnstile-response']"
  end

  test "configuration_totp flow keeps pt through method selection and returns to totps" do
    private_key = "JBSWY3DPEHPK3PXP"
    ClientOneTimePassword.create!(
      user: @user,
      private_key: private_key,
      user_one_time_password_status_id: ClientOneTimePasswordStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    pt = signed_step_up_pt(sign_app_configuration_totps_path(ri: "jp"))

    with_prosopite_paused do
      get sign_app_verification_url(scope: "configuration_totp", pt: pt, ri: "jp"),
          headers: @headers
    end

    assert_response :success
    assert_select(
      "a[href=?]",
      new_sign_app_verification_totp_path(ri: "jp", scope: "configuration_totp", pt: pt),
    )

    with_prosopite_paused do
      get new_sign_app_verification_totp_url(
        ri: "jp",
        scope: "configuration_totp",
        pt: pt,
      ), headers: @headers
    end

    assert_response :success
    assert_select "input[name='verification[scope]'][value='configuration_totp']"
    assert_select "input[name='verification[pt]'][value='#{pt}']"
    assert_select "input[name='cf-turnstile-response']"

    code = ROTP::TOTP.new(private_key).at(Time.current.to_i)
    with_prosopite_paused do
      post sign_app_verification_totp_url(ri: "jp"),
           params: { verification: { code: code, scope: "configuration_totp", pt: pt } },
           headers: @headers
    end

    assert_response :redirect
    assert_redirected_to sign_app_configuration_totps_url(ri: "jp")
  end

  test "POST returns 422 when turnstile stealth fails" do
    private_key = "JBSWY3DPEHPK3PXP"
    ClientOneTimePassword.create!(
      user: @user,
      private_key: private_key,
      user_one_time_password_status_id: ClientOneTimePasswordStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    pt = signed_step_up_pt(sign_app_configuration_emails_path(ri: "jp"))
    with_prosopite_paused do
      get sign_app_verification_url(scope: "configuration_email", pt: pt, ri: "jp"),
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

  test "POST redirects to setup when bootstrap and no usable step-up methods exist" do
    StepUp::ConfiguredMethods.stub(:call, []) do
      StepUp::AvailableMethods.stub(:call, []) do
        with_prosopite_paused do
          post sign_app_verification_totp_url(ri: "jp"),
               params: { verification: { code: "123456" } },
               headers: @headers
        end
      end
    end

    assert_response :see_other
    assert_redirected_to %r{/verification/setup/new}
  end

  private

  def signed_step_up_pt(return_to)
    step_up_pt_issuer.issue(return_to: return_to, surface: "app", session_nonce: @token.public_id)
  end

  def step_up_pt_issuer
    @step_up_pt_issuer ||= Class.new do
      include ::Redirects::SignedTargetSupport

      def issue(return_to:, surface:, session_nonce:)
        path = signed_target_internal_path(return_to)
        claims = signed_target_claims(flow: "step_up.bootstrap", surface: surface, session_nonce: session_nonce)
        issue_signed_target_token(
          payload: claims.merge("pt" => path),
          purpose: Verification::Base::STEP_UP_PATH_TARGET_TOKEN_PURPOSE,
          salt: Verification::Base::STEP_UP_PATH_TARGET_TOKEN_SALT,
          expires_in: Verification::Base::STEP_UP_TTL,
        )
      end
    end.new
  end
end
