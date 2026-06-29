# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Auth::Org::Settings::TelephonesControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_telephone_statuses
  include ActiveJob::TestHelper

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    host! @host
    @staff = operators(:one)
    @token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    satisfy_staff_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_telephone")
  end

  def request_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => @staff.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  test "sign settings telephones index renders sign settings authority" do
    get auth_org_settings_telephones_url(ri: "jp"), headers: request_headers

    assert_response :success
  end

  test "legacy sign settings telephone edit remains ceremony account-binding flow" do
    telephone = OperatorTelephone.create!(
      number: "+10000000031",
      staff: @staff,
      staff_telephone_status_id: OperatorTelephoneStatus::VERIFIED,
    )

    get edit_auth_org_settings_telephone_url(telephone.id, ri: "jp"), headers: request_headers

    assert_response :success
    assert_select(
      "form[action=?]",
      auth_org_settings_telephone_path(telephone.id, ri: "jp"),
      count: 1,
    )
  end

  test "sign settings telephone destroy mutates local account telephone" do
    telephone = OperatorTelephone.create!(
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
      delete auth_org_settings_telephone_url(telephone.id, ri: "jp"), headers: request_headers
    end

    assert_redirected_to auth_org_settings_telephones_url(ri: "jp")
  end

  test "legacy sign settings telephone new remains ceremony entry" do
    get new_auth_org_settings_telephone_url(ri: "jp"), headers: request_headers

    assert_response :success
  end

  test "legacy sign settings telephone create starts ceremony and redirects to registration edit" do
    assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
      assert_difference("OperatorTelephone.count", 1) do
        post auth_org_settings_telephones_url(ri: "jp"),
             params: { staff_telephone: { raw_number: "+10000000008" } },
             headers: request_headers
      end
    end

    assert_redirected_to edit_auth_org_settings_telephones_registration_url(ri: "jp")
  end
end
