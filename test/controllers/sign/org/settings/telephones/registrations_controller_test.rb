# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Settings::Telephones::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_telephone_statuses
  include ActiveJob::TestHelper

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
    @token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    satisfy_staff_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_telephone")

    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  def request_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => @staff.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  test "create registers telephone for current staff" do
    issuance = IdentityTelephoneCeremonyGrantIssuer.issue!(
      surface: "org",
      actor_ref: @staff.public_id,
      session_ref: @token.public_id,
      operation: "registration",
    )
    get new_sign_org_settings_telephones_registration_url(
      ri: "jp",
      telephone_ceremony_grant: issuance.grant,
    ), headers: request_headers

    assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
      assert_difference("OperatorTelephone.count", 1) do
        post sign_org_settings_telephones_registration_url(ri: "jp"),
             params: { staff_telephone: { raw_number: "+10000000009" } },
             headers: request_headers
      end
    end

    assert_redirected_to edit_sign_org_settings_telephones_registration_url(ri: "jp")
  end

  test "new renders stealth turnstile" do
    issuance = IdentityTelephoneCeremonyGrantIssuer.issue!(
      surface: "org",
      actor_ref: @staff.public_id,
      session_ref: @token.public_id,
      operation: "registration",
    )
    get(
      new_sign_org_settings_telephones_registration_url(
        ri: "jp",
        telephone_ceremony_grant: issuance.grant,
      ),
      headers: request_headers,
    )

    assert_response :success
    assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
    assert_includes response.body, 'data-turnstile-mode-value="execute"'
  end

  test "create rejects when turnstile fails" do
    CloudflareTurnstile.test_validation_response = { "success" => false }

    assert_no_difference("OperatorTelephone.count") do
      post sign_org_settings_telephones_registration_url(ri: "jp"),
           params: { staff_telephone: { raw_number: "+10000000009" } },
           headers: request_headers
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("turnstile_error")
  end

  test "create returns 422 for invalid number" do
    assert_no_difference("OperatorTelephone.count") do
      post sign_org_settings_telephones_registration_url(ri: "jp"),
           params: { staff_telephone: { raw_number: "invalid-number" } },
           headers: request_headers
    end

    assert_response :unprocessable_content
  end

  test "edit redirects if no valid session" do
    get edit_sign_org_settings_telephones_registration_url(ri: "jp"), headers: request_headers

    assert_response :redirect

    assert_redirected_to new_sign_org_settings_telephones_registration_url(ri: "jp")
  end

  test "edit renders stealth turnstile when session is valid" do
    tel = OperatorTelephone.create!(
      staff: @staff,
      raw_number: "+19999999999",
      staff_telephone_status_id: OperatorTelephoneStatus::UNVERIFIED,
      otp_private_key: "secret_credential",
      otp_expires_at: 10.minutes.from_now,
    )

    with_current_registration_telephone(tel) do
      get edit_sign_org_settings_telephones_registration_url(ri: "jp"), headers: request_headers

      assert_response :success
      assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
      assert_includes response.body, 'data-turnstile-mode-value="execute"'
      assert_select "h1", text: I18n.t("sign.app.registration.telephone.edit.page_title")
      assert_select "label", text: I18n.t("sign.app.registration.telephone.edit.code_label")
      assert_select "input[placeholder=?]", I18n.t("sign.app.registration.telephone.edit.code_placeholder")
      assert_select "input[type=submit][value=?]", I18n.t("sign.app.registration.telephone.edit.submit")
      assert_includes response.body, "電話番号"
      assert_includes response.body, "SMS"
      assert_includes response.body, I18n.t("sign.app.registration.telephone.edit.delivery_help")
    end
  end

  test "update successfully verifies telephone" do
    tel = OperatorTelephone.create!(
      staff: @staff,
      raw_number: "+19999999999",
      staff_telephone_status_id: OperatorTelephoneStatus::UNVERIFIED,
      otp_private_key: "secret_credential",
      otp_expires_at: 10.minutes.from_now,
    )

    with_current_registration_telephone(tel) do
      with_complete_staff_telephone_verification(:success, tel) do
        patch sign_org_settings_telephones_registration_url(ri: "jp"),
              params: { staff_telephone: { pass_code: "123456" } },
              headers: request_headers
      end
    end

    assert_redirected_to acme_org_settings_telephones_url(
      ri: "jp",
      host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"),
    )
    assert_equal OperatorTelephoneStatus::VERIFIED, tel.reload.staff_telephone_status_id
  end

  test "update rejects when turnstile fails" do
    tel = OperatorTelephone.create!(
      staff: @staff,
      raw_number: "+19999999998",
      staff_telephone_status_id: OperatorTelephoneStatus::UNVERIFIED,
      otp_private_key: "secret_credential",
      otp_expires_at: 10.minutes.from_now,
    )
    CloudflareTurnstile.test_validation_response = { "success" => false }

    with_current_registration_telephone(tel) do
      patch sign_org_settings_telephones_registration_url(ri: "jp"),
            params: { staff_telephone: { pass_code: "123456" } },
            headers: request_headers

      assert_response :unprocessable_content
      assert_includes response.body, I18n.t("turnstile_error")
      assert_equal OperatorTelephoneStatus::UNVERIFIED, tel.reload.staff_telephone_status_id
    end
  end

  test "otp verification concern does not directly mark staff telephone verified" do
    controller = Sign::Org::Settings::Telephones::RegistrationsController.new
    telephone = OperatorTelephone.create!(
      staff: @staff,
      raw_number: "+18888888885",
      staff_telephone_status_id: OperatorTelephoneStatus::UNVERIFIED,
      otp_private_key: ROTP::Base32.random_base32,
      otp_expires_at: 10.minutes.from_now,
    )
    otp_data = telephone.get_otp
    pass_code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s

    assert_equal :success, controller.send(:complete_staff_telephone_verification, telephone.id, pass_code)
    assert_equal OperatorTelephoneStatus::UNVERIFIED, telephone.reload.staff_telephone_status_id
  end

  private

  def with_current_registration_telephone(telephone)
    original_method =
      Sign::Org::Settings::Telephones::RegistrationsController.instance_method(:current_registration_telephone)
    Sign::Org::Settings::Telephones::RegistrationsController.define_method(:current_registration_telephone) do
      telephone
    end

    grant = IdentityTelephoneCeremonyGrantIssuer.issue!(
      surface: "org",
      actor_ref: @staff.public_id,
      session_ref: @token.public_id,
      operation: "registration",
    ).grant

    original_grant_method = Sign::Org::Settings::Telephones::RegistrationsController.instance_method(:telephone_ceremony_grant_token)
    Sign::Org::Settings::Telephones::RegistrationsController.define_method(:telephone_ceremony_grant_token) do
      grant
    end

    begin
      yield
    ensure
      Sign::Org::Settings::Telephones::RegistrationsController.define_method(
        :current_registration_telephone,
        original_method,
      )
      Sign::Org::Settings::Telephones::RegistrationsController.define_method(
        :telephone_ceremony_grant_token,
        original_grant_method,
      )
    end
  end

  def with_complete_staff_telephone_verification(status, telephone)
    original_method =
      Sign::Org::Settings::Telephones::RegistrationsController.instance_method(:complete_staff_telephone_verification)
    Sign::Org::Settings::Telephones::RegistrationsController.define_method(
      :complete_staff_telephone_verification,
    ) do |*_args, &block|
      block.call(telephone) if status == :success && block
      status
    end
    yield
  ensure
    Sign::Org::Settings::Telephones::RegistrationsController.define_method(
      :complete_staff_telephone_verification,
      original_method,
    )
  end
end
