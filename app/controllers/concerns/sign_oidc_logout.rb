# typed: false
# frozen_string_literal: true

module SignOidcLogout
  extend ActiveSupport::Concern

  OIDC_LOGOUT_REQUEST_SESSION_KEY = :oidc_logout_request

  included do
    after_action :sign_out_notice_cache_headers!, only: %i(show create)
  end

  def show
    handle_oidc_end_session_request
  end

  def create
    handle_oidc_end_session_request
  end

  private

  def handle_oidc_end_session_request
    return handle_logout_challenge_request if logout_challenge.present?

    @oidc_end_session_request = OidcEndSessionRequest.call(params: params, request: request)
    return render_oidc_end_session_error(@oidc_end_session_request) if @oidc_end_session_request.error?

    if oidc_logout_pending_request_present?
      return perform_oidc_end_session_logout(oidc_logout_pending_request) if request.post?

      return render_oidc_end_session_confirmation
    end

    if @oidc_end_session_request.post_logout_redirect_uri.present?
      store_oidc_logout_request!(@oidc_end_session_request)
      return redirect_to(sign_out_edit_path, status: :see_other)
    end

    return render_oidc_end_session_confirmation if request.get? || request.head?

    render_oidc_end_session_failure
  end

  def handle_logout_challenge_request
    @logout_transaction = logout_transaction_for_challenge
    return render_oidc_logout_completion if @logout_transaction.blank? || @logout_transaction.expired?

    return render_oidc_end_session_confirmation if request.get? || request.head?

    if @logout_transaction.expected_finalization?
      AcmeLogoutTransactionService.finalize!(logout_challenge: @logout_transaction.logout_challenge)
      return redirect_to_jump_url(
        oidc_logout_completion_redirect_url(@logout_transaction),
        status: :see_other,
      )
    end

    prepare_sign_out_completion_notice!
    logout_current_session!(reason: "user_logout")
    issue_sign_out_notice!

    advance_result = AcmeLogoutTransactionService.advance!(
      logout_challenge: @logout_transaction.logout_challenge,
      step: "acme_cleared",
    )
    transaction = advance_result.transaction || @logout_transaction

    if transaction.origin_surface == "sign"
      AcmeLogoutTransactionService.finalize!(logout_challenge: transaction.logout_challenge)
      redirect_to_jump_url(oidc_logout_completion_redirect_url(transaction), status: :see_other)
    else
      redirect_to_jump_url(
        public_send(
          "edit_sign_#{sign_surface_name}_sign_out_url",
          host: sign_service_host,
          ri: params[:ri],
          logout_challenge: transaction.logout_challenge,
        ),
        status: :see_other,
      )
    end
  rescue ActiveRecord::RecordNotFound, ArgumentError
    render_oidc_logout_completion
  end

  def perform_oidc_end_session_logout(result)
    prepare_sign_out_completion_notice!
    logout_oidc_current_session!(result)
    issue_sign_out_notice!
    notify_oidc_rps_of_logout(result)

    if result.post_logout_redirect_uri.present?
      redirect_to_jump_url(post_logout_redirect_uri_with_state(result), status: :see_other)
    else
      redirect_to(
        oidc_logout_completed_path(ri: result.legacy_ri || params[:ri]),
        status: :see_other,
      )
    end
  end

  def render_oidc_logout_completion
    @sign_out_notice = consume_sign_out_notice
    render oidc_logout_completion_template, status: :ok
  end

  def oidc_logout_completion_redirect_url(transaction)
    return transaction.completion_url unless transaction.origin_surface == "palm"

    uri = URI.parse(transaction.completion_url)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)
    query["logout_challenge"] = transaction.logout_challenge
    query["state"] = transaction.callback_state if transaction.callback_state.present?
    uri.query = query.to_query
    uri.to_s
  rescue URI::InvalidURIError
    transaction.completion_url
  end

  def render_oidc_end_session_confirmation
    render :show, status: :ok
  end

  def oidc_logout_completion_template
    :show
  end

  def render_oidc_end_session_error(result)
    if request.format.json?
      render json: { error: result.error_code, error_description: result.error_description },
             status: :bad_request
    else
      render_oidc_logout_completion
    end
  end

  def render_oidc_end_session_failure
    if request.format.json?
      render json: { error: "unprocessable_content", error_description: "logout completion is stale" },
             status: :unprocessable_content
    else
      render_oidc_logout_completion
    end
  end

  def oidc_logout_pending_request_present?
    logout_challenge.present? || session.key?(OIDC_LOGOUT_REQUEST_SESSION_KEY)
  end

  def oidc_logout_pending_request
    return OpenStruct.new(logout_challenge: logout_challenge) if logout_challenge.present?

    payload = session[OIDC_LOGOUT_REQUEST_SESSION_KEY]
    return unless payload.is_a?(Hash)

    expires_at = parse_oidc_logout_request_time(payload["expires_at"])
    return unless expires_at.present? && expires_at > Time.current

    OpenStruct.new(payload.symbolize_keys)
  end

  def store_oidc_logout_request!(result)
    session[OIDC_LOGOUT_REQUEST_SESSION_KEY] = oidc_logout_request_payload(result)
  end

  def consume_oidc_logout_request
    result = oidc_logout_pending_request
    return unless result

    session.delete(OIDC_LOGOUT_REQUEST_SESSION_KEY)
    result
  end

  def oidc_logout_request_payload(result)
    {
      "client_id" => result.client_id,
      "subject" => result.subject,
      "sid" => result.sid,
      "post_logout_redirect_uri" => result.post_logout_redirect_uri,
      "state" => result.state,
      "ui_locales" => result.ui_locales,
      "legacy_ri" => result.legacy_ri,
      "expires_at" => 5.minutes.from_now.iso8601,
    }.compact
  end

  def parse_oidc_logout_request_time(value)
    Time.zone.iso8601(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def sign_out_confirmation_request?
    current_resource.present? || current_session_public_id.present?
  end

  def logout_oidc_current_session!(result)
    begin
      resource = current_resource if respond_to?(:current_resource, true)
      session_public_id = result.sid.presence || current_session_public_id
      token_record = oidc_current_session_token(session_public_id)
      AuthenticationLogoutCurrentSession.call(
        current: Actor,
        resource: resource,
        token: token_record,
        token_class: token_class,
        session_public_id: session_public_id,
        reason: "oidc_rp_initiated_logout",
      )
      revoke_oidc_current_session_token!(token_record)
      record_logout_audit(resource) if respond_to?(:record_logout_audit, true)
    ensure
      clear_auth_cookies! if respond_to?(:clear_auth_cookies!, true)
      Actor.clear if defined?(Actor)
      reset_session
    end
  end

  def oidc_current_session_token(session_public_id)
    return if session_public_id.blank?

    token_class.includes(:device_session).find_by(public_id: session_public_id) ||
      oidc_current_session_token_by_device_session(session_public_id) ||
      oidc_current_session_token_by_sid(session_public_id)
  end

  def oidc_current_session_token_by_device_session(session_public_id)
    return unless token_class.column_names.include?("device_session_id")

    device_session = token_class.reflect_on_association(:device_session)
      &.klass&.active&.find_by(public_id: session_public_id)
    return if device_session.blank?

    token_class.currently_usable_at.where(device_session_id: device_session.id).order(created_at: :desc).first
  end

  def oidc_current_session_token_by_sid(session_public_id)
    return unless token_class.column_names.include?("oidc_sid")

    token_class.includes(:device_session).find_by(oidc_sid: session_public_id)
  end

  def revoke_oidc_current_session_token!(token_record)
    return if token_record.blank?

    token_record.reload
    token_record.revoke! if token_record.respond_to?(:revoke!) && !token_record.revoked?
  end

  def oidc_logout_confirmation_params
    return {} unless oidc_logout_pending_request_present?

    { ri: params[:ri] }.compact
  end

  def sign_out_confirmation_form_path
    return public_send(
      "acme_#{sign_surface_name}_oidc_logout_path",
      **sign_out_route_params,
      logout_challenge: logout_challenge,
    ) if oidc_logout_pending_request_present?

    sign_out_post_path
  end

  def post_logout_redirect_uri_with_state(result)
    return result.post_logout_redirect_uri if result.state.blank?

    uri = URI.parse(result.post_logout_redirect_uri)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)
    query["state"] = result.state
    uri.query = query.to_query
    uri.to_s
  end

  def notify_oidc_rps_of_logout(result)
    OidcBackchannelLogoutNotifier.call(
      resource_type: oidc_logout_resource_type,
      subject: result.subject,
      sid: result.sid,
      initiating_client_id: result.client_id,
    )
  end

  def oidc_logout_resource_type
    host = request.host.to_s
    return "operator" if oidc_logout_host_matches?(host, OidcIssuer.host_for_resource_type("operator"))
    return "visitor" if oidc_logout_host_matches?(host, OidcIssuer.host_for_resource_type("visitor"))

    "client"
  end

  def oidc_logout_host_matches?(request_host, configured_host)
    configured = URI.parse("//#{configured_host}").host.to_s
    request_host == configured
  rescue URI::InvalidURIError
    request_host == configured_host.to_s
  end

  def sign_surface_name
    controller_path.split("/").second
  end

  def logout_challenge
    params[:logout_challenge].presence
  end

  def logout_transaction_for_challenge
    return if logout_challenge.blank?

    AcmeLogoutTransactionService.find_by_logout_challenge!(logout_challenge)
  end

  def sign_service_host
    case sign_surface_name
    when "app"
      ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")
    when "com"
      ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost")
    when "org"
      ENV.fetch("SIGN_STAFF_URL", "id.org.localhost")
    else
      ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")
    end
  end
end
