# typed: false
# frozen_string_literal: true

# Controller concern for handling OAuth social authentication flow.
# Provides intent/state management and callback processing.
#
# Intent Flow:
# 1. User visits /social_auth/start?intent=link
# 2. Controller calls prepare_social_auth_intent!("link")
# 3. User is redirected to OmniAuth provider
# 4. Provider redirects back to callback
# 5. Controller calls validate_social_auth_state! and process_social_auth_callback
#
# Security:
# - State parameter prevents CSRF attacks (applied to ALL providers including Apple)
# - Intent is stored in session, not passed via URL to prevent tampering
# - State expires after 5 minutes
module SocialAuthConcern
  extend ActiveSupport::Concern

  SOCIAL_INTENT_SESSION_KEY = :social_auth_intent
  SOCIAL_USER_ID_SESSION_KEY = :social_auth_user_id
  SOCIAL_STARTED_AT_SESSION_KEY = :social_auth_started_at
  SOCIAL_FLOW_ID_SESSION_KEY = :social_auth_flow_id
  SOCIAL_PROVIDER_SESSION_KEY = :social_auth_provider
  STATE_TTL = 5.minutes
  REAUTH_TTL = 10.minutes

  VALID_INTENTS = %w(login link reauth).freeze

  included do
    rescue_from SocialAuth::BaseError, with: :handle_social_auth_error
    rescue_from ActiveRecord::RecordNotUnique, with: :handle_record_not_unique
  end

  private

  # Prepare social auth intent before redirecting to OmniAuth provider.
  # Stores intent context in session (no custom state; OmniAuth handles OAuth state).
  #
  # @param intent [String] One of: "login", "link", "reauth"
  # @return [void]
  def prepare_social_auth_intent!(intent, provider: nil)
    intent = intent.to_s
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.invalid_intent") unless VALID_INTENTS.include?(intent)

    if %w(link reauth).include?(intent) && !logged_in?
      raise SocialAuth::UnauthorizedError.new("errors.social_auth.not_logged_in")
    end

    session[SOCIAL_INTENT_SESSION_KEY] = intent
    session[SOCIAL_STARTED_AT_SESSION_KEY] = Time.current.to_i
    session[SOCIAL_FLOW_ID_SESSION_KEY] = SecureRandom.hex(16)
    session[SOCIAL_PROVIDER_SESSION_KEY] = provider
    session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY] = SecureRandom.hex(24)
    session[SocialCallbackGuard::SOCIAL_STATE_STARTED_AT_SESSION_KEY] = Time.current.to_i
    session[SocialCallbackGuard::SOCIAL_STATE_USED_AT_SESSION_KEY] = nil
    session[SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY] = provider

    if %w(link reauth).include?(intent)
      session[SOCIAL_USER_ID_SESSION_KEY] = current_resource&.id
    else
      session.delete(SOCIAL_USER_ID_SESSION_KEY)
    end

    session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]
  end

  # Validate social auth context from session for link/reauth.
  # OAuth state validation is handled by OmniAuth.
  #
  # @raise [SocialAuth::UnauthorizedError] if context is missing or expired
  def validate_social_auth_state!
    intent = current_social_auth_intent
    return if intent == "login"

    snapshot_social_auth_context(intent)

    provider = omniauth_provider
    validate_intent_presence!(intent, provider)
    validate_intent_ttl!(provider)
    validate_user_consistency!(intent)
  end

  def validate_intent_presence!(intent, provider)
    return if %w(link reauth).include?(intent) && session[SOCIAL_FLOW_ID_SESSION_KEY].present?

    Rails.event.notify("social_auth.state_missing", provider: provider)
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.state_missing")
  end

  def extract_callback_state
    params.expect(:state).to_s.presence
  end

  def current_social_auth_intent
    session[SOCIAL_INTENT_SESSION_KEY] || "login"
  end

  def clear_social_auth_intent!
    session.delete(SOCIAL_INTENT_SESSION_KEY)
    session.delete(SOCIAL_USER_ID_SESSION_KEY)
    session.delete(SOCIAL_STARTED_AT_SESSION_KEY)
    session.delete(SOCIAL_FLOW_ID_SESSION_KEY)
    session.delete(SOCIAL_PROVIDER_SESSION_KEY)
    session.delete(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    session.delete(SocialCallbackGuard::SOCIAL_STATE_STARTED_AT_SESSION_KEY)
    session.delete(SocialCallbackGuard::SOCIAL_STATE_USED_AT_SESSION_KEY)
    session.delete(SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY)
    @social_auth_intent_snapshot = nil
    @social_auth_provider_snapshot = nil
    @social_auth_user = nil
  end

  def require_recent_reauth!(ttl: REAUTH_TTL)
    return unless current_resource

    last_reauth = current_resource.last_reauth_at
    return unless last_reauth.blank? || last_reauth < ttl.ago

    Rails.event.notify(
      "social_auth.reauth_required",
      user_id: current_resource.id,
      last_reauth_at: last_reauth&.iso8601,
      required_within: Integer(ttl.to_s, 10),
    )
    raise SocialAuth::ReauthRequiredError.new("errors.social_auth.reauth_required")
  end

  def process_social_auth_callback
    auth_hash = omniauth_auth_hash
    intent = current_social_auth_intent

    result = SocialAuthService.handle_callback(
      auth_hash: auth_hash,
      current_user: social_auth_user,
      intent: intent,
    )

    clear_social_auth_intent!
    result
  end

  def omniauth_auth_hash
    request.env["omniauth.auth"]
  end

  def omniauth_provider
    omniauth_auth_hash&.provider
  end

  def omniauth_authorize_path(provider, state: nil)
    return "/auth/#{provider}" if state.blank?

    "/auth/#{provider}?state=#{CGI.escape(state)}"
  end

  def social_auth_user
    return current_resource if current_resource.present?

    intent = current_social_auth_intent
    return nil unless %w(link reauth).include?(intent)

    user_id = session[SOCIAL_USER_ID_SESSION_KEY].presence
    return nil if user_id.blank?

    @social_auth_user ||=
      begin
        klass = respond_to?(:resource_class, true) ? resource_class : User
        klass.find_by(id: user_id)
      end
  end

  def handle_social_auth_error(error)
    intent = @social_auth_intent_snapshot || current_social_auth_intent
    provider = @social_auth_provider_snapshot || omniauth_provider

    Rails.event.notify(
      "social_auth.error",
      error_class: error.class.name,
      error_message: error.message,
      status_code: error.status_code,
    )

    respond_to do |format|
      format.html do
        flash[:alert] = error.message
        clear_social_auth_intent!
        redirect_to(social_auth_failure_redirect_path_for_intent(intent: intent, provider: provider))
      end
      format.json do
        clear_social_auth_intent!
        render json: { error: error.message }, status: error.status_code
      end
    end
  end

  def handle_record_not_unique(error)
    intent = @social_auth_intent_snapshot || current_social_auth_intent
    provider = @social_auth_provider_snapshot || omniauth_provider

    Rails.event.notify(
      "social_auth.record_not_unique",
      error_message: error.message,
    )

    respond_to do |format|
      format.html do
        flash[:alert] = I18n.t("errors.social_auth.identity_conflict")
        clear_social_auth_intent!
        redirect_to(social_auth_failure_redirect_path_for_intent(intent: intent, provider: provider))
      end
      format.json do
        clear_social_auth_intent!
        render json: { error: I18n.t("errors.social_auth.identity_conflict") }, status: :conflict
      end
    end
  end

  # Override this method to customize the failure redirect path
  def social_auth_failure_redirect_path
    respond_to?(:new_sign_app_in_path) ? new_sign_app_in_path : "/"
  end

  # Override this method to customize the success redirect path
  def social_auth_success_redirect_path
    respond_to?(:sign_app_root_path) ? sign_app_root_path : "/"
  end

  def validate_intent_ttl!(provider)
    started_at = session[SOCIAL_STARTED_AT_SESSION_KEY]
    return if started_at.blank?
    return if Time.current <= Time.zone.at(Integer(started_at.to_s, 10)) + STATE_TTL

    Rails.event.notify(
      "social_auth.intent_expired",
      provider: provider,
      started_at: started_at,
    )
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.state_expired")
  end

  def validate_user_consistency!(intent)
    return unless %w(link reauth).include?(intent)

    intent_user_id = session[SOCIAL_USER_ID_SESSION_KEY].to_s
    current_id = social_auth_user&.id&.to_s

    return unless intent_user_id.blank? || current_id.blank? || intent_user_id != current_id

    raise SocialAuth::UnauthorizedError.new("errors.social_auth.user_changed")
  end

  def snapshot_social_auth_context(intent)
    @social_auth_intent_snapshot ||= intent
    @social_auth_provider_snapshot ||= omniauth_provider
  end

  def social_auth_failure_redirect_path_for_intent(intent:, provider:)
    return social_auth_failure_redirect_path unless %w(link reauth).include?(intent)

    provider_from_path = request.path.to_s.split("/auth/").last&.split("/")&.first
    provider = provider.presence || session[SOCIAL_PROVIDER_SESSION_KEY] || params[:provider] || provider_from_path

    if provider.to_s == "apple"
      return sign_app_configuration_apple_path if respond_to?(:sign_app_configuration_apple_path, true)
      if Rails.application.routes.url_helpers.respond_to?(:sign_app_configuration_apple_path)
        return Rails.application.routes.url_helpers.sign_app_configuration_apple_path
      end
    end

    return sign_app_configuration_path if respond_to?(:sign_app_configuration_path, true)
    if Rails.application.routes.url_helpers.respond_to?(:sign_app_configuration_path)
      return Rails.application.routes.url_helpers.sign_app_configuration_path
    end

    social_auth_failure_redirect_path
  end
end
