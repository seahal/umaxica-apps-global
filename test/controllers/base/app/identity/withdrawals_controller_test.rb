# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::Identity::WithdrawalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = configured_host(:base_service)
    ensure_client_reference_records!
    @client = Client.create!(status_id: ClientStatus::NOTHING)
  end

  test "new renders the withdrawal entry page for an active client" do
    get new_base_app_identity_withdrawal_url(ri: "jp"), headers: auth_headers

    assert_response :success
  end

  test "new re-renders with an error when the schedule acknowledgement is refused" do
    get new_base_app_identity_withdrawal_url(ri: "jp", ack_schedule_purge: "0"), headers: auth_headers

    assert_response :unprocessable_content
  end

  test "new advances to the deactivation confirmation once the schedule is acknowledged" do
    get new_base_app_identity_withdrawal_url(ri: "jp", ack_schedule_purge: "1"), headers: auth_headers

    assert_response :success
  end

  test "update starts the withdrawal request for a client who has none yet" do
    patch base_app_identity_withdrawal_url(ri: "jp"),
          params: { ack_schedule_purge: "1" },
          headers: auth_headers

    assert_response :redirect
    assert_equal 1, @client.client_withdrawal_flows.reload.count
    assert_predicate @client.client_withdrawal_flows.first, :withdrawal_requested?
  end

  test "update deactivates the client once the withdrawal request is already open" do
    patch base_app_identity_withdrawal_url(ri: "jp"),
          params: { ack_schedule_purge: "1" },
          headers: auth_headers

    assert_response :redirect

    # `ack_deactivate_today` is what moves the flow past the request step
    # (should_start_withdrawal_request? keys off its presence).
    patch base_app_identity_withdrawal_url(ri: "jp"),
          params: { ack_schedule_purge: "1", ack_deactivate_today: "1" },
          headers: auth_headers

    assert_response :redirect
    assert_predicate @client.reload.deactivated_at, :present?
  end

  test "update re-renders when the deactivation acknowledgement is refused" do
    patch base_app_identity_withdrawal_url(ri: "jp"),
          params: { ack_schedule_purge: "1" },
          headers: auth_headers

    assert_response :redirect

    patch base_app_identity_withdrawal_url(ri: "jp"),
          params: { ack_schedule_purge: "1", ack_deactivate_today: "0" },
          headers: auth_headers

    assert_response :unprocessable_content
    assert_nil @client.reload.deactivated_at
  end

  private

  # `new` and `update` both declare verification_required_action?, so the session needs satisfied
  # step-up material for the "withdrawal" scope. Cookies go into the integration jar rather than a
  # literal Cookie header so the Rails session cookie survives between requests.
  def auth_headers
    return @auth_headers if @auth_headers

    headers = as_user_headers(@client, host: @host)
    token = authentication_harness_latest_token(@client)
    mark_token_step_up_satisfied_for_test(token, scope: "withdrawal")
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    access_token = headers["Cookie"].to_s[/#{Regexp.escape(AuthenticationBase::ACCESS_COOKIE_KEY)}=([^;]+)/, 1]
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    cookies[ClientVerification.cookie_name] = raw_token

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
      last_step_up_audience: ("step_up:app" if token.respond_to?(:last_step_up_audience)),
      updated_at: Time.current,
    }.compact
    token.update_columns(attrs)
  end

  # DAMP local helper copy for former shared test support.
  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def ensure_client_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
  end
end
