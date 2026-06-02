# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Settings::WithdrawalsControllerTest < ActionDispatch::IntegrationTest
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
      discarded_at: 1.day.from_now,
      purged_at: 2.days.from_now,
    )
    record_withdrawal_step_up!
    @headers = withdrawal_headers
  end

  test "new requires schedule confirmation to proceed" do
    get new_sign_com_settings_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :success

    get new_sign_com_settings_withdrawal_url(ri: "jp", ack_schedule_purge: "0"), headers: @headers

    assert_response :unprocessable_content

    get new_sign_com_settings_withdrawal_url(ri: "jp", ack_schedule_purge: "1"), headers: @headers

    assert_response :success
    assert_select "label"
  end

  test "update requires deactivate confirmation" do
    patch sign_com_settings_withdrawal_url(ri: "jp"),
          params: { ack_deactivate_today: "0" },
          headers: @headers

    assert_response :unprocessable_content
    assert_nil @visitor.reload.deactivated_at
  end

  test "update rejects fresh aal1 session without withdrawal step-up" do
    clear_withdrawal_step_up!

    patch sign_com_settings_withdrawal_url(ri: "jp"),
          params: { ack_deactivate_today: "1" },
          headers: @headers

    assert_response :unauthorized
    assert_equal Verification::Base::STEP_UP_REQUIRED_MESSAGE, response.body
    assert_nil @visitor.reload.withdrawal_started_at
    assert_nil @visitor.deactivated_at
  end

  test "update rejects generic verification step-up scope" do
    mark_token_step_up_satisfied_for_test(@token, scope: "verification")

    patch sign_com_settings_withdrawal_url(ri: "jp"),
          params: { ack_deactivate_today: "1" },
          headers: @headers

    assert_response :unauthorized
    assert_nil @visitor.reload.withdrawal_started_at
    assert_nil @visitor.deactivated_at
  end

  test "update rejects unrelated step-up scope" do
    mark_token_step_up_satisfied_for_test(@token, scope: "settings_email")

    patch sign_com_settings_withdrawal_url(ri: "jp"),
          params: { ack_deactivate_today: "1" },
          headers: @headers

    assert_response :unauthorized
    assert_nil @visitor.reload.withdrawal_started_at
    assert_nil @visitor.deactivated_at
  end

  test "update rejects expired withdrawal step-up" do
    mark_token_step_up_satisfied_for_test(@token, scope: "withdrawal", at: 16.minutes.ago)

    patch sign_com_settings_withdrawal_url(ri: "jp"),
          params: { ack_deactivate_today: "1" },
          headers: @headers

    assert_response :unauthorized
    assert_nil @visitor.reload.withdrawal_started_at
    assert_nil @visitor.deactivated_at
  end

  test "update sets deactivation timestamps" do
    travel_to Time.zone.parse("2026-02-09 10:00:00") do
      patch sign_com_settings_withdrawal_url(ri: "jp"),
            params: { ack_deactivate_today: "1" },
            headers: @headers
    end

    assert_response :see_other
    assert_redirected_to edit_sign_com_settings_withdrawal_path(ri: "jp")
    assert_equal I18n.t("sign.app.settings.withdrawal.deactivate.success"), flash[:notice]

    @visitor.reload

    assert_not_nil @visitor.withdrawal_started_at
    assert_not_nil @visitor.deactivated_at
    assert_equal @visitor.deactivated_at.to_i, @visitor.discarded_at.to_i
    assert_equal @visitor.deactivated_at + 31.days, @visitor.purged_at
    assert VisitorToken.exists?(id: @token.id)

    cycle = @visitor.visitor_withdrawal_flows.recent_first.first

    assert_predicate cycle, :withdrawal_discarded?
    assert_equal 3, cycle.visitor_withdrawal_flow_events.count
  end

  test "fresh sign-in token cannot schedule withdrawal" do
    @token.update!(last_step_up_at: nil, last_step_up_scope: nil)

    patch sign_com_settings_withdrawal_url(ri: "jp"),
          params: { ack_schedule_purge: "1" },
          headers: @headers

    assert_response :unauthorized
    assert_equal Verification::Base::STEP_UP_REQUIRED_MESSAGE, response.body
    assert_nil @visitor.reload.withdrawal_started_at
  end

  test "schedule acknowledgement creates requested cycle without closing actor or revoking sessions" do
    other_token = VisitorToken.create!(
      visitor: @visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      discarded_at: 1.day.from_now,
      purged_at: 2.days.from_now,
    )

    patch sign_com_settings_withdrawal_url(ri: "jp"),
          params: { ack_schedule_purge: "1" },
          headers: @headers

    assert_response :see_other
    assert_redirected_to new_sign_com_settings_withdrawal_path(ri: "jp", ack_schedule_purge: "1")

    @visitor.reload
    @token.reload
    other_token.reload

    assert_nil @visitor.withdrawal_started_at
    assert_nil @visitor.deactivated_at
    assert_not @token.revoked?
    assert_not other_token.revoked?

    cycle = @visitor.visitor_withdrawal_flows.recent_first.first

    assert_predicate cycle, :withdrawal_requested?
    assert_equal 1, cycle.visitor_withdrawal_flow_events.count
  end

  test "wrong step-up scope cannot recover withdrawal" do
    @visitor.update!(
      deactivated_at: 10.days.ago,
      withdrawal_started_at: 10.days.ago,
      discarded_at: 1.day.from_now,
      purged_at: 21.days.from_now,
    )
    mark_token_step_up_satisfied_for_test(@token, scope: "settings_email")

    post sign_com_settings_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :unauthorized
    assert_equal Verification::Base::STEP_UP_REQUIRED_MESSAGE, response.body
    assert_not_nil @visitor.reload.deactivated_at
  end

  test "expired withdrawal step-up cannot terminate withdrawal early" do
    @visitor.update!(
      deactivated_at: 8.days.ago,
      withdrawal_started_at: 8.days.ago,
      discarded_at: 1.day.from_now,
      purged_at: 23.days.from_now,
    )
    mark_token_step_up_satisfied_for_test(@token, scope: "withdrawal", at: 16.minutes.ago)

    delete sign_com_settings_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :unauthorized
    assert_equal Verification::Base::STEP_UP_REQUIRED_MESSAGE, response.body
    assert_nil @visitor.reload.terminated_at
  end

  test "edit shows recoverable state within 31 days" do
    @visitor.update!(
      deactivated_at: 10.days.ago,
      withdrawal_started_at: 10.days.ago,
      discarded_at: 1.day.from_now,
      purged_at: 21.days.from_now,
    )

    get edit_sign_com_settings_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "復旧"
  end

  test "create recovers account within 31 days" do
    @visitor.update!(
      deactivated_at: 10.days.ago,
      withdrawal_started_at: 10.days.ago,
      discarded_at: 1.day.from_now,
      purged_at: 21.days.from_now,
    )

    post sign_com_settings_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :see_other
    assert_redirected_to sign_com_settings_url(ri: "jp")
    @visitor.reload

    assert_nil @visitor.deactivated_at
    assert_nil @visitor.withdrawal_started_at
    assert_equal Float::INFINITY, @visitor.purged_at
  end

  test "create rejects recovery without withdrawal step-up" do
    clear_withdrawal_step_up!
    @visitor.update!(
      deactivated_at: 10.days.ago,
      withdrawal_started_at: 10.days.ago,
      discarded_at: 1.day.from_now,
      purged_at: 21.days.from_now,
    )

    post sign_com_settings_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :unauthorized
    assert_not_nil @visitor.reload.deactivated_at
    assert_not_nil @visitor.withdrawal_started_at
  end

  test "create does not recover account after 31 days" do
    @visitor.update!(
      deactivated_at: 31.days.ago,
      withdrawal_started_at: 31.days.ago,
      discarded_at: 2.days.ago,
      purged_at: 1.day.ago,
    )

    post sign_com_settings_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :see_other
    @visitor.reload

    assert_not_nil @visitor.deactivated_at
  end

  test "destroy rejects early termination without withdrawal step-up" do
    clear_withdrawal_step_up!
    @visitor.update!(
      deactivated_at: 8.days.ago,
      withdrawal_started_at: 8.days.ago,
      discarded_at: 8.days.ago,
      purged_at: 23.days.from_now,
      terminated_at: nil,
    )

    delete sign_com_settings_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :unauthorized
    assert_nil @visitor.reload.terminated_at
  end

  private

  def record_withdrawal_step_up!
    mark_token_step_up_satisfied_for_test(@token, scope: "withdrawal")
  end

  def clear_withdrawal_step_up!
    @token.update!(last_step_up_at: nil, last_step_up_scope: nil)
  end

  def withdrawal_headers
    access_token = Authentication::TokenService.encode(
      @visitor,
      host: @host,
      session_public_id: @token.public_id,
      resource_type: "visitor",
      expires_at: 1.hour.from_now,
      acr: "aal1",
      amr: ["test"],
    )

    {
      "Host" => @host,
      "Authorization" => "Bearer #{access_token}",
      "X-TEST-CURRENT-VIEWER" => @visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end
end
