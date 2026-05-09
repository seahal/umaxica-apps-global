# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Configuration::Telephones::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :staffs, :staff_statuses, :staff_telephone_statuses
  include ActiveJob::TestHelper

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = staffs(:one)
    @token = StaffToken.create!(staff: @staff, status: StaffToken::STATUS_ACTIVE)
    satisfy_staff_verification(@token)
  end

  def request_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => @staff.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  test "create registers telephone for current staff" do
    assert_enqueued_jobs 1, only: SmsDeliveryJob do
      assert_difference("StaffTelephone.count", 1) do
        post sign_org_configuration_telephones_registration_url(ri: "jp"),
             params: { staff_telephone: { raw_number: "+10000000009" } },
             headers: request_headers
      end
    end

    assert_redirected_to edit_sign_org_configuration_telephones_registration_url(ri: "jp")
  end

  test "create returns 422 for invalid number" do
    assert_no_difference("StaffTelephone.count") do
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

  test "update successfully verifies telephone" do
    tel = StaffTelephone.create!(
      staff: @staff,
      raw_number: "+19999999999",
      staff_telephone_status_id: StaffTelephoneStatus::UNVERIFIED,
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
