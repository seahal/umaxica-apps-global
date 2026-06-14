# typed: false
# frozen_string_literal: true

module CoreBrowserApiBoundary
  extend ActiveSupport::Concern

  private

  attr_reader :current_resource, :current_token_payload, :current_token_record

  def require_core_browser_api_enabled!
    return if CoreBrowserCredentialContract.enabled?

    # rubocop:disable I18n/RailsI18n/DecorateString
    render_error(:service_unavailable, "Core browser API is not enabled.", status: :service_unavailable)
    # rubocop:enable I18n/RailsI18n/DecorateString
  end

  def authenticate_core_browser_cookie!
    if AuthAuthorizationHeader.access_token(request).present?
      # rubocop:disable I18n/RailsI18n/DecorateString
      render_error(:authentication_required, "Authentication is required.", status: :unauthorized)
      # rubocop:enable I18n/RailsI18n/DecorateString
      return false
    end

    token = cookies[CoreBrowserCredentialContract::ACCESS_COOKIE].to_s.presence
    unless token
      install_unauthenticated_actor!
      return false
    end

    payload = CoreBrowserCredentialContract.decode_access_token(
      token: token,
      host: request.host,
      resource_type: core_resource_type,
    )
    if payload.blank? || CoreBrowserCredentialContract.native_or_side_audience?(payload)
      # rubocop:disable I18n/RailsI18n/DecorateString
      render_error(:authentication_required, "Authentication is required.", status: :unauthorized)
      # rubocop:enable I18n/RailsI18n/DecorateString
      return false
    end

    @current_token_payload = payload
    @current_token_record = find_core_token_record(payload)
    @current_resource = find_core_resource(payload)
    unless current_token_record&.active? && current_resource&.active?
      # rubocop:disable I18n/RailsI18n/DecorateString
      render_error(:authentication_required, "Authentication is required.", status: :unauthorized)
      # rubocop:enable I18n/RailsI18n/DecorateString
      return false
    end

    install_authenticated_actor!
    true
  end

  def require_scope!(scope)
    return if Array(AuthorizationTokenClaims.scopes(current_token_payload)).include?(scope.to_s)

    # rubocop:disable I18n/RailsI18n/DecorateString
    render_error(:authorization_denied, "Authorization denied.", status: :forbidden)
    # rubocop:enable I18n/RailsI18n/DecorateString
  end

  def render_error(code, message, status:, fields: [])
    render(
      json: {
        error: {
          code: code.to_s,
          message: message,
          request_id: request.request_id,
          detail: nil,
          fields: fields,
        },
      },
      status: status,
    )
  end

  def render_csrf_failure
    # rubocop:disable I18n/RailsI18n/DecorateString
    render_error(:csrf_verification_failed, "CSRF verification failed.", status: :forbidden)
    # rubocop:enable I18n/RailsI18n/DecorateString
  end

  def render_authorization_denied
    # rubocop:disable I18n/RailsI18n/DecorateString
    render_error(:authorization_denied, "Authorization denied.", status: :forbidden)
    # rubocop:enable I18n/RailsI18n/DecorateString
  end

  def refresh_core_browser_token!
    response.set_header("Cache-Control", "no-store")

    refresh_plain = cookies[CoreBrowserCredentialContract::REFRESH_COOKIE].to_s.presence
    unless refresh_plain
      # rubocop:disable I18n/RailsI18n/DecorateString
      render_error(:authentication_required, "Authentication is required.", status: :unauthorized)
      # rubocop:enable I18n/RailsI18n/DecorateString
      return
    end

    result = AcmeRefreshTokenService.call(refresh_token: refresh_plain)
    unless result.success? && result.token.is_a?(core_token_class)
      # rubocop:disable I18n/RailsI18n/DecorateString
      render_error(:token_expired, "Token expired.", status: :unauthorized)
      # rubocop:enable I18n/RailsI18n/DecorateString
      return
    end

    resource = result.token.public_send(core_token_resource_method)
    access_expires_at = CoreBrowserCredentialContract::ACCESS_TTL.from_now
    access_token = CoreBrowserCredentialContract.encode_access_token(
      resource: resource,
      token_record: result.token,
      host: request.host,
      resource_type: core_resource_type,
      expires_at: access_expires_at,
    )

    cookies[CoreBrowserCredentialContract::ACCESS_COOKIE] =
      auth_cookie_service.auth_cookie_options(expires: access_expires_at).merge(value: access_token)
    cookies[CoreBrowserCredentialContract::REFRESH_COOKIE] =
      auth_cookie_service.auth_cookie_options(expires: result.token.discarded_at).merge(value: result.refresh_token)

    render json: { refreshed: true }, status: :ok
  end

  def verify_core_browser_api_csrf!
    return if request.get? || request.head? || request.options?

    token = request.headers["X-CSRF-Token"].to_s
    return if token.present? && valid_authenticity_token?(session, token)

    render_csrf_failure
  end

  def current_actor
    Actor.context
  end

  def current_policy_user
    current_actor&.authz&.policy_user
  end

  def install_unauthenticated_actor!
    Actor.clear
  end

  def install_authenticated_actor!
    Actor.clear
    # The Core Browser API boundary is the Core BFF browser cookie flow, so the
    # transport/channel axes are known and concrete here.
    context = ActorValuesContext.new(
      subject: current_resource,
      actor_type: core_actor_type,
      account: nil,
      tenant: nil,
      tld: core_actor_tld,
      surface: :core,
      transport: :cookie,
      channel: :browser,
      authn: Actor::Authentication.new(
        login_public_id: current_token_record.public_id,
        access_claims: current_token_payload,
        acr: current_token_payload["acr"],
        amr: current_token_payload["amr"],
        actor_type: core_actor_type,
        actor_id: current_resource.id,
        restricted: current_token_record.respond_to?(:restricted?) && current_token_record.restricted?,
      ),
      authz: Actor::Authz.new(
        policy_user: current_resource,
        token_claims: current_token_payload,
        surface: core_actor_tld,
      ),
      preferences: Actor::Preference::NULL,
      configuration: Actor::Configuration::NULL,
      step_up: Actor::StepUp::NULL,
      selection: Actor::SelectedContext::NULL,
      trace_id: request.request_id,
      span_id: nil,
    )
    Actor.install_context!(**context.to_h)
  end

  def find_core_token_record(payload)
    sid = AuthorizationTokenClaims.session_id(payload).to_s
    return nil if sid.blank?

    core_token_class.find_by(public_id: sid) || core_token_class.find_by(oidc_sid: sid)
  end

  def find_core_resource(payload)
    subject = AuthorizationTokenClaims.subject(payload).to_s
    return nil if subject.blank?

    core_resource_class.find_by(id: subject)
  end

  def core_actor_tld
    raise NotImplementedError, "controller must define core_actor_tld"
  end

  def core_actor_type
    core_resource_type.to_sym
  end

  def core_resource_class
    raise NotImplementedError, "controller must define core_resource_class"
  end

  def core_token_class
    raise NotImplementedError, "controller must define core_token_class"
  end

  def core_resource_type
    raise NotImplementedError, "controller must define core_resource_type"
  end

  def core_token_resource_method
    case core_resource_type
    when "operator" then :staff
    when "visitor" then :visitor
    else :user
    end
  end

  def auth_cookie_service
    @auth_cookie_service ||= AuthenticationCookieService.new(cookies, request)
  end
end
