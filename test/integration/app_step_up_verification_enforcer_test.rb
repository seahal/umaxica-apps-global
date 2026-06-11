# typed: false
# frozen_string_literal: true

require "test_helper"
class AppStepUpVerificationEnforcerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_totp_credential_statuses, :client_chronicle_events, :client_chronicle_levels

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = Client.create!(status_id: ClientStatus::NOTHING)
    @email = ClientEmail.create!(
      address: "step-up-enforcer-#{SecureRandom.hex(4)}@example.com",
      user: @user,
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    @headers = as_user_headers(@user, host: @host)
    @token = ClientToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "GET protected endpoint redirects to setup when configured methods are zero" do
    @user.update!(mfa_status_id: ClientMfaStatus::UNCONFIGURED)

    StepUpConfiguredMethods.stub(:call, []) do
      StepUpAvailableMethods.stub(:call, []) do
        get edit_sign_app_settings_email_url(@email.public_id, ri: "jp"), headers: @headers
      end
    end

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification/setup/new", uri.path
    assert_predicate query["pt"], :present?
  end

  test "GET protected endpoint redirects to verification when configured is non-zero but usable is zero" do
    StepUpConfiguredMethods.stub(:call, [:email_otp]) do
      StepUpAvailableMethods.stub(:call, []) do
        get edit_sign_app_settings_email_url(@email.public_id, ri: "jp"), headers: @headers
      end
    end

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification", uri.path
    assert_predicate query["pt"], :present?
  end

  test "GET protected endpoint redirects to verification when usable methods exist" do
    ClientTotpCredential.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    get edit_sign_app_settings_email_url(@email.public_id, ri: "jp"), headers: @headers

    assert_response :redirect
    uri = URI.parse(response.location)

    assert_equal "/verification", uri.path
  end

  test "POST protected endpoint returns 401 plain when step-up is missing and usable methods exist" do
    ClientTotpCredential.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    post sign_app_settings_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :unauthorized
    assert_equal VerificationBase::STEP_UP_REQUIRED_MESSAGE, response.body
  end

  test "successful verification enables protected POST and records audit" do
    private_key = "JBSWY3DPEHPK3PXP"
    ClientTotpCredential.create!(
      user: @user,
      private_key: private_key,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    get new_sign_app_settings_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :redirect
    redirect_uri = URI.parse(response.location)
    redirect_query = Rack::Utils.parse_query(redirect_uri.query)

    assert_equal "/verification", redirect_uri.path
    assert_equal "withdrawal", redirect_query["scope"]

    get sign_app_verification_url(scope: "withdrawal", pt: redirect_query.fetch("pt"), ri: "jp"), headers: @headers

    assert_response :success

    # Seed the acme-issued ceremony transaction the real acme intent route would create. sign no
    # longer self-issues grants; it can only emit a result against an acme-issued ceremony.
    signed_step_up_grant_for(
      actor: @user, token: @token, scope: "withdrawal",
      return_to: new_sign_app_settings_withdrawal_path(ri: "jp"), surface: "app",
    )

    code = ROTP::TOTP.new(private_key).at(Time.current.to_i)
    post sign_app_verification_totp_url(ri: "jp"),
         params: { verification: { code: code } },
         headers: @headers

    assert_response :success
    assert_includes response.body, "step-up-completion-form"

    assert ClientChronicle.exists?(
      actor_type: "Client",
      actor_id: @user.id,
      event_id: ClientChronicleEvent::STEP_UP_VERIFIED,
      subject_type: "Client",
      subject_id: @user.id,
    )

    submit_step_up_completion_if_present!(
      host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
      headers: as_user_headers(
        @user,
        host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
        session_public_id: @token.public_id,
      ),
    )

    post sign_app_settings_withdrawal_url(ri: "jp"), headers: @headers

    assert_not_equal 401, response.status
  end
end
