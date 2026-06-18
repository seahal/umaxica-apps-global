# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Settings::WithdrawalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @acme_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "withdrawal-#{SecureRandom.hex(4)}@example.com")
    @visitor.update_columns(created_at: 120.days.ago, updated_at: 120.days.ago)
    @visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10 ** 8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @token = VisitorToken.create!(
      visitor: @visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      discarded_at: 1.day.from_now,
      purged_at: 2.days.from_now,
    )
  end

  test "new_redirects_to_acme_account_authority" do
    get new_sign_com_settings_withdrawal_url(ri: "jp"), headers: session_headers

    assert_redirect_to_acme_withdrawal
  end

  test "update_redirect_is_not_account_lifecycle_mutation" do
    patch sign_com_settings_withdrawal_url(ri: "jp"),
          params: { ack_deactivate_today: "1" },
          headers: session_headers

    assert_redirect_to_acme_withdrawal
    assert_nil @visitor.reload.withdrawal_started_at
    assert_nil @visitor.deactivated_at
  end

  test "create_redirect_is_not_withdrawal_recovery_mutation" do
    @visitor.update!(
      deactivated_at: 10.days.ago,
      withdrawal_started_at: 10.days.ago,
      discarded_at: 1.day.from_now,
      purged_at: 21.days.from_now,
    )

    post sign_com_settings_withdrawal_url(ri: "jp"), headers: session_headers

    assert_redirect_to_acme_withdrawal
    assert_not_nil @visitor.reload.withdrawal_started_at
    assert_not_nil @visitor.deactivated_at
  end

  test "destroy_redirect_is_not_withdrawal_termination_mutation" do
    @visitor.update!(
      deactivated_at: 8.days.ago,
      withdrawal_started_at: 8.days.ago,
      discarded_at: 1.day.from_now,
      purged_at: 23.days.from_now,
      terminated_at: nil,
    )

    delete sign_com_settings_withdrawal_url(ri: "jp"), headers: session_headers

    assert_redirect_to_acme_withdrawal
    assert_nil @visitor.reload.terminated_at
  end

  private

  def session_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @visitor.id.to_s,
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
