# frozen_string_literal: true

require "test_helper"

class WithdrawalCeremonyReentryTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "deactivated client obtains ceremony after valid email otp without normal auth cookies" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host
    client = create_client
    client.update!(
      withdrawal_started_at: 2.hours.ago,
      deactivated_at: 90.minutes.ago,
      discarded_at: 31.days.from_now,
      purged_at: 31.days.from_now,
    )
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    email = ClientEmail.create!(
      user: client,
      address: "reentry-client@example.test",
      confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    fake_adapter = Object.new
    fake_adapter.define_singleton_method(:deliver) { |**_args| true }

    OtpAdapter.stub(:for, fake_adapter) do
      post base_app_identity_withdrawal_session_url(ri: "jp", host: host),
           params: { withdrawal_reentry: { address: "reentry-client@example.test" } },
           headers: browser_headers
    end

    assert_response :success
    otp_data = email.reload.get_otp
    pass_code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s

    assert_difference -> { ClientWithdrawalCeremony.count }, 1 do
      post base_app_identity_withdrawal_session_url(ri: "jp", host: host),
           params: { pass_code: pass_code },
           headers: browser_headers
    end

    assert_response :see_other
    assert_redirected_to edit_base_app_identity_withdrawal_path(ri: "jp")
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert ClientOccurrence.where(event_type: "withdrawal.ceremony_issued").exists?
  end

  test "active client does not obtain withdrawal ceremony through reentry" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host
    client = create_client
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientEmail.create!(
      user: client,
      address: "active-client@example.test",
      confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    assert_no_difference -> { ClientWithdrawalCeremony.count } do
      post base_app_identity_withdrawal_session_url(ri: "jp", host: host),
           params: { withdrawal_reentry: { address: "active-client@example.test" } },
           headers: browser_headers
    end

    assert_response :success
  end

  test "deactivated visitor obtains ceremony after valid email otp without normal auth cookies" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")
    host! host
    visitor = create_visitor
    visitor.update!(
      withdrawal_started_at: 2.hours.ago,
      deactivated_at: 90.minutes.ago,
      discarded_at: 31.days.from_now,
      purged_at: 31.days.from_now,
    )
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    email = VisitorEmail.create!(
      visitor: visitor,
      address: "reentry-visitor@example.test",
      confirm_policy: "1",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    fake_adapter = Object.new
    fake_adapter.define_singleton_method(:deliver) { |**_args| true }

    OtpAdapter.stub(:for, fake_adapter) do
      post base_com_identity_withdrawal_session_url(ri: "jp", host: host),
           params: { withdrawal_reentry: { address: "reentry-visitor@example.test" } },
           headers: browser_headers
    end

    assert_response :success
    otp_data = email.reload.get_otp
    pass_code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s

    assert_difference -> { VisitorWithdrawalCeremony.count }, 1 do
      post base_com_identity_withdrawal_session_url(ri: "jp", host: host),
           params: { pass_code: pass_code },
           headers: browser_headers
    end

    assert_response :see_other
    assert_redirected_to edit_base_com_identity_withdrawal_path(ri: "jp")
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert VisitorOccurrence.where(event_type: "withdrawal.ceremony_issued").exists?
  end

  private

  def browser_headers
    csrf_token = "test_csrf_token"
    cookies["csrf_token"] = csrf_token
    {
      "Client-Agent" => "Mozilla/5.0",
      "X-CSRF-Token" => csrf_token,
    }
  end

  def create_client
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    Client.create!(
      status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
      mfa_level_id: ClientMfaLevel::NOTHING,
      mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
  end

  def create_visitor
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    Visitor.create!(
      status_id: VisitorStatus::NOTHING,
      visibility_id: VisitorVisibility::VISITOR,
      mfa_level_id: VisitorMfaLevel::NOTHING,
      mfa_status_id: VisitorMfaStatus::UNCONFIGURED,
    )
  end
end
