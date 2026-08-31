# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Com::Identity::WithdrawalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = configured_host(:base_corporate)
    @visitor = create_verified_visitor_with_email(email_address: "com-withdrawal-#{SecureRandom.hex(4)}@example.com")
  end

  test "new renders the withdrawal entry page for an active visitor" do
    get new_base_com_identity_withdrawal_url(ri: "jp"), headers: auth_headers

    assert_response :success
  end

  test "new re-renders with an error when the schedule acknowledgement is missing" do
    get new_base_com_identity_withdrawal_url(ri: "jp", ack_schedule_purge: "0"), headers: auth_headers

    assert_response :unprocessable_content
  end

  test "new advances to the deactivation confirmation once the schedule is acknowledged" do
    get new_base_com_identity_withdrawal_url(ri: "jp", ack_schedule_purge: "1"), headers: auth_headers

    assert_response :success
  end

  test "update starts the withdrawal request for a visitor who has none yet" do
    patch base_com_identity_withdrawal_url(ri: "jp"),
          params: { ack_schedule_purge: "1" },
          headers: auth_headers

    assert_response :redirect
    assert_equal 1, @visitor.visitor_withdrawal_flows.reload.count
    assert_predicate @visitor.visitor_withdrawal_flows.first, :withdrawal_requested?
  end

  test "update deactivates the visitor once the withdrawal request is already open" do
    patch base_com_identity_withdrawal_url(ri: "jp"),
          params: { ack_schedule_purge: "1" },
          headers: auth_headers

    assert_response :redirect

    # `ack_deactivate_today` is what moves the flow past the request step
    # (should_start_withdrawal_request? keys off its presence).
    patch base_com_identity_withdrawal_url(ri: "jp"),
          params: { ack_schedule_purge: "1", ack_deactivate_today: "1" },
          headers: auth_headers

    assert_response :redirect
    assert_predicate @visitor.reload.deactivated_at, :present?
  end

  test "update re-renders when the deactivation acknowledgement is refused" do
    patch base_com_identity_withdrawal_url(ri: "jp"),
          params: { ack_schedule_purge: "1" },
          headers: auth_headers

    assert_response :redirect

    patch base_com_identity_withdrawal_url(ri: "jp"),
          params: { ack_schedule_purge: "1", ack_deactivate_today: "0" },
          headers: auth_headers

    assert_response :unprocessable_content
    assert_nil @visitor.reload.deactivated_at
  end

  private

  # `new` and `update` both declare verification_required_action?, so the session needs satisfied
  # step-up material for the "withdrawal" scope. Cookies go into the integration jar rather than a
  # literal Cookie header so the Rails session cookie survives between requests.
  def auth_headers
    return @auth_headers if @auth_headers

    headers = as_visitor_headers(@visitor, host: @host)
    token = authentication_harness_latest_token(@visitor)
    mark_token_step_up_satisfied_for_test(token, scope: "withdrawal")
    _verification, raw_token = VisitorVerification.issue_for_token!(token: token)
    access_token = headers["Cookie"].to_s[/#{Regexp.escape(AuthenticationBase::ACCESS_COOKIE_KEY)}=([^;]+)/, 1]
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    cookies[VisitorVerification.cookie_name] = raw_token

    @auth_headers = headers.except("Cookie", "HTTP_COOKIE")
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    attrs = {
      last_step_up_at: at,
      last_step_up_scope: scope.presence || "verification",
      last_step_up_aal: ("aal2" if token.respond_to?(:last_step_up_aal)),
      last_step_up_method: ("passkey" if token.respond_to?(:last_step_up_method)),
      last_step_up_session_public_id: (token.public_id if token.respond_to?(:last_step_up_session_public_id)),
      last_step_up_purpose: ("step_up" if token.respond_to?(:last_step_up_purpose)),
      last_step_up_audience: ("step_up:com" if token.respond_to?(:last_step_up_audience)),
      updated_at: Time.current,
    }.compact
    token.update_columns(attrs)
  end

  # DAMP local helper copy for former shared test support.
  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor_id: visitor.id,
      address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    visitor.reload
    visitor.refresh_mfa_status! if visitor.respond_to?(:refresh_mfa_status!)
    visitor.reload
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
  end
end
