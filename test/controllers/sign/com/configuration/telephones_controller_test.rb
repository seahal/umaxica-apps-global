# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Configuration::TelephonesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "telephones-#{SecureRandom.hex(4)}@example.com")
    @visitor.visitor_telephones.create!(
      number: "+10000000027",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    satisfy_visitor_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "configuration_telephone")
  end

  def request_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @visitor.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  test "should get index" do
    get sign_com_configuration_telephones_url(ri: "jp"), headers: request_headers

    assert_response :success
  end

  test "index redirects visitors without a verified telephone to registration" do
    visitor = create_verified_visitor_with_email(email_address: "unverified-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    satisfy_visitor_verification(token)

    headers = {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => visitor.id,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    get sign_com_configuration_telephones_url(ri: "jp"), headers: headers

    assert_response :redirect

    assert_redirected_to new_sign_com_configuration_telephones_registration_url(ri: "jp")
  end

  test "create registers telephone" do
    assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
      assert_difference("VisitorTelephone.count", 1) do
        post sign_com_configuration_telephones_url(ri: "jp"),
             params: { user_telephone: { raw_number: "+10000000028" } },
             headers: request_headers
      end
    end

    created = VisitorTelephone.order(created_at: :desc).first

    assert_redirected_to edit_sign_com_configuration_telephone_url(created.id, ri: "jp")
  end

  test "create reuses existing telephone and sends sms when same number is submitted again" do
    existing = VisitorTelephone.create!(
      number: "+10000000029",
      visitor: @visitor,
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
      assert_no_difference("VisitorTelephone.count") do
        post sign_com_configuration_telephones_url(ri: "jp"),
             params: { user_telephone: { raw_number: "+10000000029" } },
             headers: request_headers
      end
    end

    assert_redirected_to edit_sign_com_configuration_telephone_url(existing.id, ri: "jp")
  end

  test "destroy removes telephone when not last method" do
    tel1 = VisitorTelephone.create!(
      number: "+10000000030",
      visitor: @visitor,
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    VisitorTelephone.create!(
      number: "+10000000031",
      visitor: @visitor,
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    assert_difference("VisitorTelephone.count", -1) do
      delete sign_com_configuration_telephone_url(tel1, ri: "jp"), headers: request_headers
    end

    assert_response :see_other
  end
end
