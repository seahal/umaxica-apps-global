# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Configuration::EmailsControllerTest < ActionDispatch::IntegrationTest
  fixtures :staffs, :staff_statuses, :staff_email_statuses, :staff_telephone_statuses

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
    get sign_org_configuration_emails_url(ri: "jp"), headers: request_headers

    assert_response :success
  end

  test "index displays verified status" do
    email = StaffEmail.create!(
      address: "verified-staff@example.com",
      staff: @staff,
      staff_email_status_id: StaffEmailStatus::VERIFIED,
    )

    get sign_org_configuration_emails_url(ri: "jp"), headers: request_headers

    assert_response :success
    assert_includes response.body, "認証済み"
    assert_includes response.body, email.address
  end

  test "destroy removes email when not last method" do
    email1 = StaffEmail.create!(
      address: "delete-staff1@example.com",
      staff: @staff,
      staff_email_status_id: StaffEmailStatus::VERIFIED,
    )
    StaffEmail.create!(
      address: "delete-staff2@example.com",
      staff: @staff,
      staff_email_status_id: StaffEmailStatus::VERIFIED,
    )

    assert_difference("StaffEmail.count", -1) do
      delete sign_org_configuration_email_url(email1, ri: "jp"), headers: request_headers
    end

    assert_response :see_other
  end

  test "destroy blocks removing last email when no supporting method remains" do
    email = StaffEmail.create!(
      address: "last-staff@example.com",
      staff: @staff,
      staff_email_status_id: StaffEmailStatus::VERIFIED,
    )
    StaffTelephone.create!(
      number: "+15550001112",
      staff: @staff,
      staff_telephone_status_id: StaffTelephoneStatus::VERIFIED,
    )

    assert_no_difference("StaffEmail.count") do
      delete sign_org_configuration_email_url(email, ri: "jp"), headers: request_headers
    end

    assert_redirected_to sign_org_configuration_emails_url(ri: "jp")
  end

  test "destroy blocks removing an undeletable email" do
    email = StaffEmail.create!(
      address: "protected-staff@example.com",
      staff: @staff,
      staff_email_status_id: StaffEmailStatus::VERIFIED,
      undeletable: true,
    )
    StaffEmail.create!(
      address: "other-staff@example.com",
      staff: @staff,
      staff_email_status_id: StaffEmailStatus::VERIFIED,
    )

    assert_no_difference("StaffEmail.count") do
      delete sign_org_configuration_email_url(email, ri: "jp"), headers: request_headers
    end

    assert_redirected_to sign_org_configuration_emails_url(ri: "jp")
    assert_equal I18n.t("sign.org.configuration.email.destroy.protected"), flash[:alert]
  end
end
