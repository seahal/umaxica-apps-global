# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Configuration::TelephonesControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_identity_statuses, :operator_email_statuses, :operator_telephone_statuses
  include ActiveJob::TestHelper

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
    @token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    satisfy_staff_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "configuration_telephone")
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
    assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
      assert_difference("OperatorTelephone.count", 1) do
        post sign_org_configuration_telephones_url(ri: "jp"),
             params: { staff_telephone: { raw_number: "+10000000008" } },
             headers: request_headers
      end
    end

    created = OperatorTelephone.order(created_at: :desc).first

    assert_redirected_to edit_sign_org_configuration_telephone_url(created.id, ri: "jp")
  end

  test "create reuses existing telephone and sends sms when same number is submitted again" do
    existing = OperatorTelephone.create!(
      number: "+10000000012",
      staff: @staff,
      staff_telephone_status_id: OperatorTelephoneStatus::VERIFIED,
    )

    assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
      assert_no_difference("OperatorTelephone.count") do
        post sign_org_configuration_telephones_url(ri: "jp"),
             params: { staff_telephone: { raw_number: "+10000000012" } },
             headers: request_headers
      end
    end

    assert_redirected_to edit_sign_org_configuration_telephone_url(existing.id, ri: "jp")
  end

  test "destroy removes telephone when not last method" do
    tel1 = OperatorTelephone.create!(
      number: "+10000000000",
      staff: @staff,
      staff_telephone_status_id: OperatorTelephoneStatus::VERIFIED,
    )
    OperatorTelephone.create!(
      number: "+10000000001",
      staff: @staff,
      staff_telephone_status_id: OperatorTelephoneStatus::VERIFIED,
    )

    assert_difference("OperatorTelephone.count", -1) do
      delete sign_org_configuration_telephone_url(tel1, ri: "jp"), headers: request_headers
    end

    assert_response :see_other
  end
end
