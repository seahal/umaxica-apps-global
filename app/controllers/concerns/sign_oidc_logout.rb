# typed: false
# frozen_string_literal: true

module SignOidcLogout
  extend ActiveSupport::Concern

  included do
    helper_method :oidc_logout_confirmation_params
  end

  def show
    handle_oidc_end_session_request
  end

  def create
    handle_oidc_end_session_request
  end

  private

  def handle_oidc_end_session_request
    @oidc_end_session_request = OidcEndSessionRequest.call(params: params, request: request)
    return render_oidc_end_session_error(@oidc_end_session_request) if @oidc_end_session_request.error?
    return render :show,
                  status: :ok if request.get? || request.head? || @oidc_end_session_request.requires_confirmation?

    perform_oidc_end_session_logout(@oidc_end_session_request)
  end

  def perform_oidc_end_session_logout(result)
    prepare_sign_out_completion_notice!
    logout_oidc_current_session!(result)
    issue_sign_out_notice!
    notify_oidc_rps_of_logout(result)

    if result.post_logout_redirect_uri.present?
      redirect_to(post_logout_redirect_uri_with_state(result), allow_other_host: true, status: :see_other)
    else
      redirect_to(oidc_logout_completed_path(ri: result.legacy_ri || params[:ri]), status: :see_other)
    end
  end

  def render_oidc_end_session_error(result)
    render json: { error: result.error_code, error_description: result.error_description },
           status: :bad_request
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

    device_session = token_class.reflect_on_association(:device_session)&.klass&.active&.find_by(public_id: session_public_id)
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
    return {} unless @oidc_end_session_request

    params = {}
    params[:id_token_hint] = request.params[:id_token_hint] if request.params[:id_token_hint].present?
    params[:logout_request] = request.params[:logout_request] if request.params[:logout_request].present?
    params[:client_id] = request.params[:client_id] if request.params[:client_id].present?
    params[:post_logout_redirect_uri] = @oidc_end_session_request.post_logout_redirect_uri \
      if @oidc_end_session_request.post_logout_redirect_uri.present?
    params[:state] = @oidc_end_session_request.state if @oidc_end_session_request.state.present?
    params[:ui_locales] = @oidc_end_session_request.ui_locales if @oidc_end_session_request.ui_locales.present?
    params[:ri] = request.params[:ri] if request.params[:ri].present?
    params
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
end
