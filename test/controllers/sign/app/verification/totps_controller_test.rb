# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::App::Verification::TotpsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_totp_credential_statuses

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
    ClientTotpCredential.create!(
      user: @user,
      private_key: private_key,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    return_to = sign_app_settings_emails_path(ri: "jp")
    pt = signed_step_up_pt(return_to)
    grant = signed_step_up_grant_for(
      actor: @user, token: @token, scope: "settings_email", return_to: return_to, surface: "app",
    )
    with_prosopite_paused do
      get sign_app_verification_url(scope: "settings_email", pt: pt, ri: "jp", step_up_ceremony_grant: grant),
          headers: @headers
    end

    assert_response :success

    with_prosopite_paused do
      get new_sign_app_verification_totp_url(ri: "jp"), headers: @headers
    end

    assert_response :success
    assert_select "input[name='cf-turnstile-response']"
    assert_select "h1", text: I18n.t("sign.app.verification.edit.title")
    assert_select "label", text: I18n.t("sign.app.verification.edit.code_label")
    assert_select "input[placeholder=?]", I18n.t("sign.app.verification.edit.code_placeholder")
    assert_select "input[type=submit][value=?]", I18n.t("sign.app.verification.edit.submit")
    assert_includes response.body, "認証アプリ"
    assert_includes response.body, I18n.t("sign.app.verification.edit.totp_help")
    assert_not_includes response.body, "届きます"
    assert_not_includes response.body, "送信され"

    session[:step_up_email_otp] = { "expires_at" => 5.minutes.from_now.to_i }

    code = ROTP::TOTP.new(private_key).at(Time.current.to_i)

    with_prosopite_paused do
      post sign_app_verification_totp_url(ri: "jp"),
           params: { verification: { code: code } },
           headers: @headers
    end

    assert_response :success
    assert_includes response.body, "step-up-completion-form"

    # sign no longer writes freshness; acme commits it on completion (below).
    assert_nil session[:step_up]
    assert_nil session[:step_up_email_otp]

    submit_step_up_completion_if_present!(
      headers: as_user_headers(
        @user,
        host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
        session_public_id: @token.public_id,
      ),
    )

    assert_response :redirect
    assert_not_nil @token.reload.last_step_up_at
    assert_equal "settings_email", @token.last_step_up_scope
  end

  test "successful totp consumes the step-up session and cannot be replayed" do
    private_key = "JBSWY3DPEHPK3PXP"
    ClientTotpCredential.create!(
      user: @user,
      private_key: private_key,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )
    return_to = sign_app_settings_emails_path(ri: "jp")
    pt = signed_step_up_pt(return_to)
    grant = signed_step_up_grant_for(
      actor: @user, token: @token, scope: "settings_email", return_to: return_to, surface: "app",
    )

    with_prosopite_paused do
      get sign_app_verification_url(scope: "settings_email", pt: pt, ri: "jp", step_up_ceremony_grant: grant),
          headers: @headers
    end

    assert_response :success
    assert_equal 1, ClientStepUpSession.where(user_token: @token).count

    code = ROTP::TOTP.new(private_key).at(Time.current.to_i)

    assert_no_difference -> { ClientVerification.count } do
      with_prosopite_paused do
        post sign_app_verification_totp_url(ri: "jp"),
             params: { verification: { code: code } },
             headers: @headers
      end
    end

    assert_response :success
    assert_includes response.body, "step-up-completion-form"
    assert_equal 0, ClientStepUpSession.where(user_token: @token).count

    # sign no longer writes freshness; acme commits it when it consumes the result.
    assert_no_difference -> { ClientVerification.count } do
      with_prosopite_paused do
        post sign_app_verification_totp_url(ri: "jp"),
             params: { verification: { code: code } },
             headers: @headers
      end
    end

    assert_response :redirect
    assert_redirected_to sign_app_settings_url(ri: "jp")
  end

  test "renders new on failure" do
    private_key = "JBSWY3DPEHPK3PXP"
    ClientTotpCredential.create!(
      user: @user,
      private_key: private_key,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    pt = signed_step_up_pt(sign_app_settings_emails_path(ri: "jp"))
    with_prosopite_paused do
      get sign_app_verification_url(scope: "settings_email", pt: pt, ri: "jp"),
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
    ClientTotpCredential.create!(
      user: @user,
      private_key: private_key,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    pt = signed_step_up_pt(sign_app_settings_emails_path(ri: "jp"))
    with_prosopite_paused do
      get sign_app_verification_url(scope: "settings_email", pt: pt, ri: "jp"),
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
    ClientTotpCredential.create!(
      user: @user,
      private_key: private_key,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    pt = signed_step_up_pt(sign_app_settings_emails_path(ri: "jp"))
    with_prosopite_paused do
      get sign_app_verification_url(scope: "settings_email", pt: pt, ri: "jp"),
          headers: @headers
    end

    assert_response :success

    with_prosopite_paused do
      get new_sign_app_verification_totp_url(
        ri: "jp",
        scope: "settings_email",
        pt: pt,
      ), headers: @headers
    end

    assert_response :success
    assert_select "input[name='verification[scope]'][value='settings_email']"
    assert_select "input[name='verification[pt]'][value='#{pt}']"
    assert_select "input[name='cf-turnstile-response']"
  end

  test "settings_totp flow keeps pt through method selection and returns to totps" do
    private_key = "JBSWY3DPEHPK3PXP"
    ClientTotpCredential.create!(
      user: @user,
      private_key: private_key,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    return_to = sign_app_settings_totps_path(ri: "jp")
    freeze_time do
      pt = signed_step_up_pt(return_to)
      grant = signed_step_up_grant_for(
        actor: @user, token: @token, scope: "settings_totp", return_to: return_to, surface: "app",
      )

      with_prosopite_paused do
        get sign_app_verification_url(scope: "settings_totp", pt: pt, ri: "jp", step_up_ceremony_grant: grant),
            headers: @headers
      end

      assert_response :success
      assert_select(
        "a[href=?]",
        new_sign_app_verification_totp_path(ri: "jp", scope: "settings_totp", pt: pt),
      )

      with_prosopite_paused do
        get new_sign_app_verification_totp_url(
          ri: "jp",
          scope: "settings_totp",
          pt: pt,
        ), headers: @headers
      end

      assert_response :success
      assert_select "input[name='verification[scope]'][value='settings_totp']"
      assert_select "input[name='verification[pt]'][value='#{pt}']"
      assert_select "input[name='cf-turnstile-response']"

      code = ROTP::TOTP.new(private_key).at(Time.current.to_i)
      with_prosopite_paused do
        post sign_app_verification_totp_url(ri: "jp"),
             params: { verification: { code: code, scope: "settings_totp", pt: pt } },
             headers: @headers
      end

      assert_response :success
      assert_includes response.body, "step-up-completion-form"
      submit_step_up_completion_if_present!(
        headers: as_user_headers(
          @user,
          host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
          session_public_id: @token.public_id,
        ),
      )

      assert_response :redirect
      assert_not_nil @token.reload.last_step_up_at
      assert_equal "settings_totp", @token.last_step_up_scope
    end
  end

  test "POST returns 422 when turnstile stealth fails" do
    private_key = "JBSWY3DPEHPK3PXP"
    ClientTotpCredential.create!(
      user: @user,
      private_key: private_key,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    pt = signed_step_up_pt(sign_app_settings_emails_path(ri: "jp"))
    with_prosopite_paused do
      get sign_app_verification_url(scope: "settings_email", pt: pt, ri: "jp"),
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
    StepUpConfiguredMethods.stub(:call, []) do
      StepUpAvailableMethods.stub(:call, []) do
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
      include ::RedirectsSignedTargetSupport

      def issue(return_to:, surface:, session_nonce:)
        path = signed_target_internal_path(return_to)
        claims = signed_target_claims(flow: "step_up.bootstrap", surface: surface, session_nonce: session_nonce)
        issue_signed_target_token(
          payload: claims.merge("pt" => path),
          purpose: VerificationBase::STEP_UP_PATH_TARGET_TOKEN_PURPOSE,
          salt: VerificationBase::STEP_UP_PATH_TARGET_TOKEN_SALT,
          expires_in: VerificationBase::STEP_UP_TTL,
        )
      end
    end.new
  end
end
