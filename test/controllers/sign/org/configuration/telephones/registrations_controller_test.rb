# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Configuration::Telephones::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_identity_statuses, :operator_telephone_statuses
  include ActiveJob::TestHelper

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
    @token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    satisfy_staff_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "configuration_telephone")

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
    assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
      assert_difference("OperatorTelephone.count", 1) do
        post sign_org_configuration_telephones_registration_url(ri: "jp"),
             params: { staff_telephone: { raw_number: "+10000000009" } },
             headers: request_headers
      end
    end

    assert_redirected_to edit_sign_org_configuration_telephones_registration_url(ri: "jp")
  end

  test "new renders stealth turnstile" do
    get new_sign_org_configuration_telephones_registration_url(ri: "jp"), headers: request_headers

    assert_response :success
    assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
    assert_includes response.body, "turnstile.execute"
  end

  test "create rejects when turnstile fails" do
    CloudflareTurnstile.test_validation_response = { "success" => false }

    assert_no_difference("OperatorTelephone.count") do
      post sign_org_configuration_telephones_registration_url(ri: "jp"),
           params: { staff_telephone: { raw_number: "+10000000009" } },
           headers: request_headers
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("turnstile_error")
  end

  test "create returns 422 for invalid number" do
    assert_no_difference("OperatorTelephone.count") do
      post sign_org_configuration_telephones_registration_url(ri: "jp"),
           params: { staff_telephone: { raw_number: "invalid-number" } },
           headers: request_headers
    end

    assert_response :unprocessable_content
  end

  test "edit redirects if no valid session" do
    get edit_sign_org_configuration_telephones_registration_url(ri: "jp"), headers: request_headers

    assert_response :redirect

    assert_redirected_to new_sign_org_configuration_telephones_registration_url(ri: "jp")
  end

  test "edit renders stealth turnstile when session is valid" do
    tel = OperatorTelephone.create!(
      staff: @staff,
      raw_number: "+19999999999",
      staff_telephone_status_id: OperatorTelephoneStatus::UNVERIFIED,
      otp_private_key: "secret",
      otp_expires_at: 10.minutes.from_now,
    )

    with_current_registration_telephone(tel) do
      get edit_sign_org_configuration_telephones_registration_url(ri: "jp"), headers: request_headers

      assert_response :success
      assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
      assert_includes response.body, "turnstile.execute"
    end
  end

  test "update successfully verifies telephone" do
    tel = OperatorTelephone.create!(
      staff: @staff,
      raw_number: "+19999999999",
      staff_telephone_status_id: OperatorTelephoneStatus::UNVERIFIED,
      otp_private_key: "secret",
      otp_expires_at: 10.minutes.from_now,
    )

    with_current_registration_telephone(tel) do
      with_complete_staff_telephone_verification(:success, tel) do
        patch sign_org_configuration_telephones_registration_url(ri: "jp"),
              params: { staff_telephone: { pass_code: "123456" } },
              headers: request_headers
      end
    end

    assert_redirected_to sign_org_configuration_telephones_url(ri: "jp")
  end

  test "update rejects when turnstile fails" do
    tel = OperatorTelephone.create!(
      staff: @staff,
      raw_number: "+19999999998",
      staff_telephone_status_id: OperatorTelephoneStatus::UNVERIFIED,
      otp_private_key: "secret",
      otp_expires_at: 10.minutes.from_now,
    )
    CloudflareTurnstile.test_validation_response = { "success" => false }

    with_current_registration_telephone(tel) do
      patch sign_org_configuration_telephones_registration_url(ri: "jp"),
            params: { staff_telephone: { pass_code: "123456" } },
            headers: request_headers

      assert_response :unprocessable_content
      assert_includes response.body, I18n.t("turnstile_error")
      assert_equal OperatorTelephoneStatus::UNVERIFIED, tel.reload.staff_telephone_status_id
    end
  end

  private

  def with_current_registration_telephone(telephone)
    original_method =
      Sign::Org::Configuration::Telephones::RegistrationsController.instance_method(:current_registration_telephone)
    Sign::Org::Configuration::Telephones::RegistrationsController.define_method(:current_registration_telephone) do
      telephone
    end
    yield
  ensure
    Sign::Org::Configuration::Telephones::RegistrationsController.define_method(
      :current_registration_telephone,
      original_method,
    )
  end

  def with_complete_staff_telephone_verification(status, telephone)
    original_method =
      Sign::Org::Configuration::Telephones::RegistrationsController.instance_method(:complete_staff_telephone_verification)
    Sign::Org::Configuration::Telephones::RegistrationsController.define_method(
      :complete_staff_telephone_verification,
    ) do |*_args, &block|
      block.call(telephone) if status == :success && block
      status
    end
    yield
  ensure
    Sign::Org::Configuration::Telephones::RegistrationsController.define_method(
      :complete_staff_telephone_verification,
      original_method,
    )
  end
end
