# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Configuration::TelephonesControllerTest < ActionDispatch::IntegrationTest
  fixtures :staffs, :staff_statuses, :staff_email_statuses, :staff_telephone_statuses
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

  test "should get index" do
    get sign_org_configuration_telephones_url(ri: "jp"), headers: request_headers

    assert_response :success
  end

  test "create registers telephone" do
    assert_enqueued_jobs 1, only: SmsDeliveryJob do
      assert_difference("StaffTelephone.count", 1) do
        post sign_org_configuration_telephones_url(ri: "jp"),
             params: { staff_telephone: { raw_number: "+10000000008" } },
             headers: request_headers
      end
    end

    created = StaffTelephone.order(created_at: :desc).first

    assert_redirected_to edit_sign_org_configuration_telephone_url(created.id, ri: "jp")
  end

  test "create reuses existing telephone and sends sms when same number is submitted again" do
    existing = StaffTelephone.create!(
      number: "+10000000012",
      staff: @staff,
      staff_telephone_status_id: StaffTelephoneStatus::VERIFIED,
    )

    assert_enqueued_jobs 1, only: SmsDeliveryJob do
      assert_no_difference("StaffTelephone.count") do
        post sign_org_configuration_telephones_url(ri: "jp"),
             params: { staff_telephone: { raw_number: "+10000000012" } },
             headers: request_headers
      end
    end

    assert_redirected_to edit_sign_org_configuration_telephone_url(existing.id, ri: "jp")
  end

  test "destroy removes telephone when not last method" do
    tel1 = StaffTelephone.create!(
      number: "+10000000000",
      staff: @staff,
      staff_telephone_status_id: StaffTelephoneStatus::VERIFIED,
    )
    StaffTelephone.create!(
      number: "+10000000001",
      staff: @staff,
      staff_telephone_status_id: StaffTelephoneStatus::VERIFIED,
    )

    assert_difference("StaffTelephone.count", -1) do
      delete sign_org_configuration_telephone_url(tel1, ri: "jp"), headers: request_headers
    end

    assert_response :see_other
  end

  test "destroy blocks removal when last method" do
    telephone = StaffTelephone.create!(
      number: "+10000000002",
      staff: @staff,
      staff_telephone_status_id: StaffTelephoneStatus::VERIFIED,
    )

    assert_no_difference("StaffTelephone.count") do
      delete sign_org_configuration_telephone_url(telephone, ri: "jp"), headers: request_headers
    end

    assert_redirected_to sign_org_configuration_telephones_url(ri: "jp")
  end
end
