# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::Com::Configuration::WithdrawalsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    host! @host
    @visitor = create_verified_visitor_with_email(email_address: "withdrawal-#{SecureRandom.hex(4)}@example.com")
    @visitor.update_columns(created_at: 120.days.ago, updated_at: 120.days.ago)
    @visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @token = VisitorToken.create!(
      visitor: @visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      lapses_at: 1.day.from_now,
      purge_at: 2.days.from_now,
    )
    perform_withdrawal_step_up!
    @headers = as_visitor_headers(@visitor, host: @host).merge("X-TEST-SESSION-PUBLIC-ID" => @token.public_id)
  end

  test "new requires schedule confirmation to proceed" do
    get new_sign_com_configuration_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :success

    get new_sign_com_configuration_withdrawal_url(ri: "jp", ack_schedule_purge: "0"), headers: @headers

    assert_response :unprocessable_content

    get new_sign_com_configuration_withdrawal_url(ri: "jp", ack_schedule_purge: "1"), headers: @headers

    assert_response :success
    assert_select "label"
  end

  test "update requires deactivate confirmation" do
    patch sign_com_configuration_withdrawal_url(ri: "jp"),
          params: { ack_deactivate_today: "0" },
          headers: @headers

    assert_response :unprocessable_content
    assert_nil @visitor.reload.deactivated_at
  end

  test "update sets deactivation timestamps" do
    travel_to Time.zone.parse("2026-02-09 10:00:00") do
      patch sign_com_configuration_withdrawal_url(ri: "jp"),
            params: { ack_deactivate_today: "1" },
            headers: @headers
    end

    assert_response :see_other
    assert_redirected_to edit_sign_com_configuration_url(ri: "jp")

    @visitor.reload

    assert_not_nil @visitor.withdrawal_started_at
    assert_not_nil @visitor.deactivated_at
    assert_equal @visitor.deactivated_at + 31.days, @visitor.purge_at
  end

  test "edit shows recoverable state within 31 days" do
    @visitor.update!(
      deactivated_at: 10.days.ago,
      withdrawal_started_at: 10.days.ago,
      lapses_at: 1.day.from_now,
      purge_at: 21.days.from_now,
    )

    get edit_sign_com_configuration_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "復旧"
  end

  test "create recovers account within 31 days" do
    @visitor.update!(
      deactivated_at: 10.days.ago,
      withdrawal_started_at: 10.days.ago,
      lapses_at: 1.day.from_now,
      purge_at: 21.days.from_now,
    )

    post sign_com_configuration_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :see_other
    assert_redirected_to sign_com_configuration_url(ri: "jp")
    @visitor.reload

    assert_nil @visitor.deactivated_at
    assert_nil @visitor.withdrawal_started_at
    assert_equal Float::INFINITY, @visitor.purge_at
  end

  test "create does not recover account after 31 days" do
    @visitor.update!(
      deactivated_at: 31.days.ago,
      withdrawal_started_at: 31.days.ago,
      lapses_at: 2.days.ago,
      purge_at: 1.day.ago,
    )

    post sign_com_configuration_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :see_other
    @visitor.reload

    assert_not_nil @visitor.deactivated_at
  end

  private

  def perform_withdrawal_step_up!
    return_to = Base64.urlsafe_encode64(sign_com_configuration_withdrawal_path(ri: "jp"))
    headers = host_headers(@host).merge(
      "X-TEST-CURRENT-RESOURCE" => @visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    )

    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      Email::App::RegistrationMailer.stub(:with, OpenStruct.new(create: OpenStruct.new(deliver_later: true))) do
        get(sign_com_verification_url(scope: "withdrawal", return_to: return_to, ri: "jp"), headers: headers)

        assert_response :success

        get(new_sign_com_verification_email_url(ri: "jp"), headers: headers)

        assert_response :redirect
        nonce = response.location[%r{/verification/emails/([^/]+)/edit}, 1]

        with_verify_email_otp_stub(true) do
          patch(
            sign_com_verification_email_url(nonce, ri: "jp"),
            params: { verification: { code: "123456" } },
            headers: headers,
          )
        end

        assert_response :redirect
        @token.update!(last_step_up_at: Time.current, last_step_up_scope: "withdrawal")
      end
    end
  end

  def with_verify_email_otp_stub(result)
    original_method = Sign::Com::Verification::EmailsController.instance_method(:verify_email_otp!)
    Sign::Com::Verification::EmailsController.define_method(:verify_email_otp!) { result }
    yield
  ensure
    Sign::Com::Verification::EmailsController.define_method(:verify_email_otp!, original_method)
  end
end
