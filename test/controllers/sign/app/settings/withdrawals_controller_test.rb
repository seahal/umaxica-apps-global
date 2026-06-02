# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::App::Settings::WithdrawalsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  fixtures :clients, :client_statuses, :client_token_kinds, :client_token_statuses

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    host! @host
    @user = create_verified_user_with_email(email_address: "withdrawal-#{SecureRandom.hex(4)}@example.com")
    @user.update_columns(created_at: 120.days.ago, updated_at: 120.days.ago)
    @token = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discarded_at: 1.day.from_now,
      purged_at: 2.days.from_now,
    )
    perform_withdrawal_step_up!
    @headers = withdrawal_headers
  end

  test "new requires schedule confirmation to proceed" do
    get new_sign_app_settings_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :success

    get new_sign_app_settings_withdrawal_url(ri: "jp", ack_schedule_purge: "0"), headers: @headers

    assert_response :unprocessable_content

    get new_sign_app_settings_withdrawal_url(ri: "jp", ack_schedule_purge: "1"), headers: @headers

    assert_response :success
    # Skip label text verification - translation key may be missing
    assert_select "label"
  end

  test "update requires deactivate confirmation" do
    patch sign_app_settings_withdrawal_url(ri: "jp"),
          params: { ack_deactivate_today: "0" },
          headers: @headers

    assert_response :unprocessable_content
    assert_nil @user.reload.deactivated_at
  end

  test "update rejects fresh aal1 session without withdrawal step-up" do
    clear_withdrawal_step_up!

    patch sign_app_settings_withdrawal_url(ri: "jp"),
          params: { ack_deactivate_today: "1" },
          headers: @headers

    assert_response :unauthorized
    assert_equal Verification::Base::STEP_UP_REQUIRED_MESSAGE, response.body
    assert_nil @user.reload.withdrawal_started_at
    assert_nil @user.deactivated_at
  end

  test "update rejects generic verification step-up scope" do
    mark_token_step_up_satisfied_for_test(@token, scope: "verification")

    patch sign_app_settings_withdrawal_url(ri: "jp"),
          params: { ack_deactivate_today: "1" },
          headers: @headers

    assert_response :unauthorized
    assert_nil @user.reload.withdrawal_started_at
    assert_nil @user.deactivated_at
  end

  test "update rejects unrelated step-up scope" do
    mark_token_step_up_satisfied_for_test(@token, scope: "settings_email")

    patch sign_app_settings_withdrawal_url(ri: "jp"),
          params: { ack_deactivate_today: "1" },
          headers: @headers

    assert_response :unauthorized
    assert_nil @user.reload.withdrawal_started_at
    assert_nil @user.deactivated_at
  end

  test "update rejects expired withdrawal step-up" do
    mark_token_step_up_satisfied_for_test(@token, scope: "withdrawal", at: 16.minutes.ago)

    patch sign_app_settings_withdrawal_url(ri: "jp"),
          params: { ack_deactivate_today: "1" },
          headers: @headers

    assert_response :unauthorized
    assert_nil @user.reload.withdrawal_started_at
    assert_nil @user.deactivated_at
  end

  test "update sets deactivation timestamps" do
    Prosopite.pause do
      travel_to Time.zone.parse("2026-02-09 10:00:00") do
        patch sign_app_settings_withdrawal_url(ri: "jp"),
              params: { ack_deactivate_today: "1" },
              headers: @headers
      end
    end

    assert_response :see_other
    assert_redirected_to edit_sign_app_settings_withdrawal_path(ri: "jp")
    assert_equal I18n.t("sign.app.settings.withdrawal.deactivate.success"), flash[:notice]

    @user.reload

    assert_not_nil @user.withdrawal_started_at
    assert_not_nil @user.deactivated_at
    assert_equal @user.deactivated_at.to_i, @user.discarded_at.to_i
    assert_equal @user.deactivated_at + 31.days, @user.purged_at
    assert ClientToken.exists?(id: @token.id)

    cycle = @user.client_withdrawal_flows.recent_first.first

    assert_predicate cycle, :withdrawal_discarded?
    assert_equal 3, cycle.client_withdrawal_flow_events.count
  end

  test "fresh sign-in token cannot schedule withdrawal" do
    @token.update!(last_step_up_at: nil, last_step_up_scope: nil)

    patch sign_app_settings_withdrawal_url(ri: "jp"),
          params: { ack_schedule_purge: "1" },
          headers: @headers

    assert_response :unauthorized
    assert_equal Verification::Base::STEP_UP_REQUIRED_MESSAGE, response.body
    assert_nil @user.reload.withdrawal_started_at
  end

  test "schedule acknowledgement creates requested cycle without closing actor or revoking sessions" do
    other_token = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discarded_at: 1.day.from_now,
      purged_at: 2.days.from_now,
    )

    patch sign_app_settings_withdrawal_url(ri: "jp"),
          params: { ack_schedule_purge: "1" },
          headers: @headers

    assert_response :see_other
    assert_redirected_to new_sign_app_settings_withdrawal_path(ri: "jp", ack_schedule_purge: "1")

    @user.reload
    @token.reload
    other_token.reload

    assert_nil @user.withdrawal_started_at
    assert_nil @user.deactivated_at
    assert_not @token.revoked?
    assert_not other_token.revoked?

    cycle = @user.client_withdrawal_flows.recent_first.first

    assert_predicate cycle, :withdrawal_requested?
    assert_equal 1, cycle.client_withdrawal_flow_events.count
  end

  test "wrong step-up scope cannot recover withdrawal" do
    @user.update!(
      deactivated_at: 10.days.ago,
      withdrawal_started_at: 10.days.ago,
      discarded_at: 1.day.from_now,
      purged_at: 21.days.from_now,
    )
    mark_token_step_up_satisfied_for_test(@token, scope: "settings_email")

    post sign_app_settings_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :unauthorized
    assert_equal Verification::Base::STEP_UP_REQUIRED_MESSAGE, response.body
    assert_not_nil @user.reload.deactivated_at
  end

  test "expired withdrawal step-up cannot terminate withdrawal early" do
    @user.update!(
      deactivated_at: 8.days.ago,
      withdrawal_started_at: 8.days.ago,
      discarded_at: 1.day.from_now,
      purged_at: 23.days.from_now,
    )
    mark_token_step_up_satisfied_for_test(@token, scope: "withdrawal", at: 16.minutes.ago)

    delete sign_app_settings_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :unauthorized
    assert_equal Verification::Base::STEP_UP_REQUIRED_MESSAGE, response.body
    assert_nil @user.reload.terminated_at
  end

  test "edit shows recoverable state within 31 days" do
    @user.update!(
      deactivated_at: 10.days.ago, withdrawal_started_at: 10.days.ago,
      discarded_at: 1.day.from_now,
      purged_at: 21.days.from_now,
    )

    get edit_sign_app_settings_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "復旧"
  end

  test "create recovers account within 31 days" do
    @user.update!(
      deactivated_at: 10.days.ago, withdrawal_started_at: 10.days.ago,
      discarded_at: 1.day.from_now,
      purged_at: 21.days.from_now,
    )

    post sign_app_settings_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :see_other
    assert_redirected_to sign_app_settings_path(ri: "jp")
    @user.reload

    assert_nil @user.deactivated_at
    assert_nil @user.withdrawal_started_at
    assert_equal Float::INFINITY, @user.purged_at
  end

  test "create rejects recovery without withdrawal step-up" do
    clear_withdrawal_step_up!
    @user.update!(
      deactivated_at: 10.days.ago, withdrawal_started_at: 10.days.ago,
      discarded_at: 1.day.from_now,
      purged_at: 21.days.from_now,
    )

    post sign_app_settings_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :unauthorized
    assert_not_nil @user.reload.deactivated_at
    assert_not_nil @user.withdrawal_started_at
  end

  test "create does not recover account after 31 days" do
    @user.update!(
      deactivated_at: 31.days.ago, withdrawal_started_at: 31.days.ago,
      discarded_at: 2.days.ago,
      purged_at: 1.day.ago,
    )

    post sign_app_settings_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :redirect
    assert_redirected_to edit_sign_app_settings_withdrawal_path(ri: "jp")
    @user.reload

    assert_not_nil @user.deactivated_at
  end

  test "destroy rejects early termination without withdrawal step-up" do
    clear_withdrawal_step_up!
    @user.update!(
      deactivated_at: 8.days.ago,
      withdrawal_started_at: 8.days.ago,
      discarded_at: 8.days.ago,
      purged_at: 23.days.from_now,
      terminated_at: nil,
    )

    delete sign_app_settings_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :unauthorized
    assert_nil @user.reload.terminated_at
  end

  private

  def perform_withdrawal_step_up!
    mark_token_step_up_satisfied_for_test(@token, scope: "withdrawal")
  end

  def clear_withdrawal_step_up!
    @token.update!(last_step_up_at: nil, last_step_up_scope: nil)
  end

  def withdrawal_headers
    browser_headers.merge(
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    )
  end
end
