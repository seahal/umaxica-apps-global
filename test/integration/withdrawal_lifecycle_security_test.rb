# frozen_string_literal: true

require "test_helper"

class WithdrawalLifecycleSecurityTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("AUTH_SERVICE_URL")
    host! @host
    @user = create_verified_user_with_email(email_address: "withdrawal-p0-#{SecureRandom.hex(4)}@example.com")
    @user.update_columns(created_at: 120.days.ago, updated_at: 120.days.ago)
    @token = ClientToken.create!(user: @user, discarded_at: 1.day.from_now, purged_at: 2.days.from_now)
    @other_token = ClientToken.create!(user: @user, discarded_at: 1.day.from_now, purged_at: 2.days.from_now)
    mark_token_step_up_satisfied_for_test(@token, scope: "withdrawal")
  end

  test "confirmed withdrawal revokes other sessions but preserves the continuation session" do
    freeze_time do
      patch auth_app_settings_withdrawal_url(ri: "jp", host: @host),
            params: { ack_schedule_purge: "1" },
            headers: headers_for(@token)
      patch auth_app_settings_withdrawal_url(ri: "jp", host: @host),
            params: { ack_deactivate_today: "1" },
            headers: headers_for(@token)
    end

    assert_response :see_other

    assert_not @token.reload.revoked?, "current MFA-verified continuation session must remain usable"
    assert_predicate @other_token.reload, :revoked?, "other sessions must be revoked once withdrawal is active"
    assert_not_nil @user.reload.withdrawal_started_at
    assert_not_nil @user.deactivated_at
  end

  test "withdrawal recovery is rejected before one hour and after purge deadline" do
    freeze_time do
      patch auth_app_settings_withdrawal_url(ri: "jp", host: @host),
            params: { ack_schedule_purge: "1" },
            headers: headers_for(@token)
      patch auth_app_settings_withdrawal_url(ri: "jp", host: @host),
            params: { ack_deactivate_today: "1" },
            headers: headers_for(@token)

      travel 10.minutes
      post auth_app_settings_withdrawal_url(ri: "jp", host: @host), headers: headers_for(@token)

      assert_response :see_other
      assert_not_nil @user.reload.deactivated_at

      @user.update_columns(deactivated_at: 31.days.ago, discarded_at: 31.days.ago, purged_at: 1.minute.ago)
      mark_token_step_up_satisfied_for_test(@token, scope: "withdrawal")
      post auth_app_settings_withdrawal_url(ri: "jp", host: @host), headers: headers_for(@token)

      assert_response :see_other
      assert_not_nil @user.reload.deactivated_at
    end
  end

  private

  def headers_for(token)
    browser_headers.merge(
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    )
  end
end
