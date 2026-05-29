# typed: false
# frozen_string_literal: true

require "test_helper"
class AppStepUpVerificationEnforcerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_one_time_password_statuses, :client_chronicle_events, :client_chronicle_levels

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
    @user.update!(multi_factor_status_id: ClientMultiFactorStatus::UNCONFIGURED)

    StepUp::ConfiguredMethods.stub(:call, []) do
      StepUp::AvailableMethods.stub(:call, []) do
        get edit_sign_app_configuration_email_url(@email.public_id, ri: "jp"), headers: @headers
      end
    end

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification/setup/new", uri.path
    assert_predicate query["pt"], :present?
  end

  test "GET protected endpoint redirects to verification when configured is non-zero but usable is zero" do
    StepUp::ConfiguredMethods.stub(:call, [:email_otp]) do
      StepUp::AvailableMethods.stub(:call, []) do
        get edit_sign_app_configuration_email_url(@email.public_id, ri: "jp"), headers: @headers
      end
    end

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification", uri.path
    assert_predicate query["pt"], :present?
  end

  test "GET protected endpoint redirects to verification when usable methods exist" do
    ClientOneTimePassword.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      user_one_time_password_status_id: ClientOneTimePasswordStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    get edit_sign_app_configuration_email_url(@email.public_id, ri: "jp"), headers: @headers

    assert_response :redirect
    uri = URI.parse(response.location)

    assert_equal "/verification", uri.path
  end

  test "POST protected endpoint returns 401 plain when step-up is missing and usable methods exist" do
    ClientOneTimePassword.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      user_one_time_password_status_id: ClientOneTimePasswordStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    post sign_app_configuration_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :unauthorized
    assert_equal Verification::Base::STEP_UP_REQUIRED_MESSAGE, response.body
  end

  test "successful verification enables protected POST and records audit" do
    private_key = "JBSWY3DPEHPK3PXP"
    ClientOneTimePassword.create!(
      user: @user,
      private_key: private_key,
      user_one_time_password_status_id: ClientOneTimePasswordStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    get new_sign_app_configuration_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :redirect
    redirect_uri = URI.parse(response.location)
    redirect_query = Rack::Utils.parse_query(redirect_uri.query)

    assert_equal "/verification", redirect_uri.path
    assert_equal "withdrawal", redirect_query["scope"]

    get sign_app_verification_url(scope: "withdrawal", pt: redirect_query.fetch("pt"), ri: "jp"), headers: @headers

    assert_response :success

    code = ROTP::TOTP.new(private_key).at(Time.current.to_i)
    post sign_app_verification_totp_url(ri: "jp"),
         params: { verification: { code: code } },
         headers: @headers

    assert_response :redirect
    assert_redirected_to new_sign_app_configuration_withdrawal_url(ri: "jp")
    assert response_has_cookie?(ClientVerification.cookie_name)

    assert ClientVerification.active.exists?(user_token_id: @token.id)
    assert ClientChronicle.exists?(
      actor_type: "Client",
      actor_id: @user.id,
      event_id: ClientChronicleEvent::STEP_UP_VERIFIED,
      subject_type: "Client",
      subject_id: @user.id,
    )

    post sign_app_configuration_withdrawal_url(ri: "jp"), headers: @headers

    assert_not_equal 401, response.status
  end
end
