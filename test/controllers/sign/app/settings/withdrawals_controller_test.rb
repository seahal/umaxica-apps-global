# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Settings::WithdrawalsControllerTest < ActionDispatch::IntegrationTest
  fixtures :client_token_kinds, :client_token_statuses

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @user = create_verified_user_with_email(email_address: "withdrawal-#{SecureRandom.hex(4)}@example.com")
    @user.update_columns(created_at: 120.days.ago, updated_at: 120.days.ago)
    @token = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discarded_at: 1.day.from_now,
      purged_at: 2.days.from_now,
    )
  end

  test "new_redirects_to_acme_account_authority" do
    get new_sign_app_settings_withdrawal_url(ri: "jp"), headers: session_headers

    assert_redirect_to_acme_withdrawal
  end

  test "update_redirect_is_not_account_lifecycle_mutation" do
    patch sign_app_settings_withdrawal_url(ri: "jp"),
          params: { ack_deactivate_today: "1" },
          headers: session_headers

    assert_redirect_to_acme_withdrawal
    assert_nil @user.reload.withdrawal_started_at
    assert_nil @user.deactivated_at
  end

  test "create_redirect_is_not_withdrawal_recovery_mutation" do
    @user.update!(
      deactivated_at: 10.days.ago,
      withdrawal_started_at: 10.days.ago,
      discarded_at: 1.day.from_now,
      purged_at: 21.days.from_now,
    )

    post sign_app_settings_withdrawal_url(ri: "jp"), headers: session_headers

    assert_redirect_to_acme_withdrawal
    assert_not_nil @user.reload.withdrawal_started_at
    assert_not_nil @user.deactivated_at
  end

  test "destroy_redirect_is_not_withdrawal_termination_mutation" do
    @user.update!(
      deactivated_at: 8.days.ago,
      withdrawal_started_at: 8.days.ago,
      discarded_at: 1.day.from_now,
      purged_at: 23.days.from_now,
      terminated_at: nil,
    )

    delete sign_app_settings_withdrawal_url(ri: "jp"), headers: session_headers

    assert_redirect_to_acme_withdrawal
    assert_nil @user.reload.terminated_at
  end

  private

  def session_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  def assert_redirect_to_acme_withdrawal
    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal @acme_host, location.host
    assert_equal "/settings/withdrawal", location.path
    assert_equal "ri=jp", location.query
  end
end
