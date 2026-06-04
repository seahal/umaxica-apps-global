# typed: false
# frozen_string_literal: true

# Controller concern for handling OAuth social authentication flow.
# Provides intent/state management and callback processing.
#
# Intent Flow:
# 1. User submits POST /social/auth/:provider/continue?intent=link
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
  SOCIAL_PT_SESSION_KEY = :social_auth_pt
  SOCIAL_ENTRY_SESSION_KEY = :social_auth_entry
  SOCIAL_RI_SESSION_KEY = :social_auth_ri
  # Stores the social ceremony transaction id, not the JWT grant. Keeping the
  # JWT in the cookie-backed session can exceed the 4KB cookie limit.
  SOCIAL_CEREMONY_GRANT_SESSION_KEY = :social_ceremony_grant
  STATE_TTL = 5.minutes
  STEP_UP_TTL = 10.minutes
  SOCIAL_LINK_SCOPE = "social_link"

  VALID_INTENTS = %w(login link step_up).freeze

  private

  # Prepare social auth intent before redirecting to OmniAuth provider.
  # Stores intent context in session (no custom state; OmniAuth handles OAuth state).
  #
  # @param intent [String] One of: "login", "link"
  # @return [void]
  def prepare_social_auth_intent!(intent, provider: nil, pt: nil, entry: nil, ri: nil)
    intent = intent.to_s
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.invalid_intent") unless VALID_INTENTS.include?(intent)

    validate_social_auth_login_requirement!(intent)
    if intent == "link"
      @social_auth_intent_snapshot = intent
      @social_auth_provider_snapshot = provider
      authorize_social_auth_link!(social_auth_authorization_resource)
      require_recent_step_up!
    end

    store_social_auth_intent_context(intent, provider: provider, pt: pt, entry: entry, ri: ri)
    store_oauth_callback_state(provider)
    store_social_auth_user_context(intent)

    session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]
  end

  def validate_social_auth_login_requirement!(intent)
    return unless intent == "link" && !logged_in?

    raise SocialAuth::UnauthorizedError.new("errors.social_auth.not_logged_in")
  end

  def store_social_auth_intent_context(intent, provider:, pt:, entry:, ri:)
    session[SOCIAL_INTENT_SESSION_KEY] = intent
    session[SOCIAL_STARTED_AT_SESSION_KEY] = Time.current.to_i
    session[SOCIAL_FLOW_ID_SESSION_KEY] = SecureRandom.hex(16)
    session[SOCIAL_PROVIDER_SESSION_KEY] = provider
    session[SOCIAL_ENTRY_SESSION_KEY] = entry if entry.present?
    session[SOCIAL_RI_SESSION_KEY] = ri if ri.present?
    if pt.present?
      session[SOCIAL_PT_SESSION_KEY] = pt
    else
      session.delete(SOCIAL_PT_SESSION_KEY)
    end
  end

  def store_oauth_callback_state(provider)
    state = SecureRandom.hex(24)
    session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY] = state
    session[SocialCallbackGuard::SOCIAL_STATE_STARTED_AT_SESSION_KEY] = Time.current.to_i
    session[SocialCallbackGuard::SOCIAL_STATE_USED_AT_SESSION_KEY] = nil
    session[SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY] = provider
    SocialAuth::CallbackStateStore.issue!(
      state: state,
      provider: provider,
      intent: session[SOCIAL_INTENT_SESSION_KEY],
    )
  end

  def store_social_auth_user_context(intent)
    if intent == "link"
      session[SOCIAL_USER_ID_SESSION_KEY] = current_resource&.id
    else
      session.delete(SOCIAL_USER_ID_SESSION_KEY)
    end
  end

  # Validate social auth context from session for link intent.
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
    return if intent == "link" && session[SOCIAL_FLOW_ID_SESSION_KEY].present?

    Rails.logger.info(Jit::LogEvent.format("social_auth.state_missing", provider: provider))
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.state_missing")
  end

  def extract_callback_state
    request.parameters["state"].to_s.presence
  end

  def current_social_auth_intent
    session[SOCIAL_INTENT_SESSION_KEY] || "login"
  end

  def current_social_auth_pt
    session[SOCIAL_PT_SESSION_KEY].presence
  end

  def current_social_auth_entry
    session[SOCIAL_ENTRY_SESSION_KEY].presence
  end

  def current_social_auth_ri
    session[SOCIAL_RI_SESSION_KEY].presence
  end

  def clear_social_auth_intent!
    session.delete(SOCIAL_INTENT_SESSION_KEY)
    session.delete(SOCIAL_USER_ID_SESSION_KEY)
    session.delete(SOCIAL_STARTED_AT_SESSION_KEY)
    session.delete(SOCIAL_FLOW_ID_SESSION_KEY)
    session.delete(SOCIAL_PROVIDER_SESSION_KEY)
    session.delete(SOCIAL_PT_SESSION_KEY)
    session.delete(SOCIAL_ENTRY_SESSION_KEY)
    session.delete(SOCIAL_RI_SESSION_KEY)
    session.delete(SOCIAL_CEREMONY_GRANT_SESSION_KEY)
    session.delete(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    session.delete(SocialCallbackGuard::SOCIAL_STATE_STARTED_AT_SESSION_KEY)
    session.delete(SocialCallbackGuard::SOCIAL_STATE_USED_AT_SESSION_KEY)
    session.delete(SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY)
    @social_auth_intent_snapshot = nil
    @social_auth_provider_snapshot = nil
    @social_auth_user = nil
  end

  def require_recent_step_up!(ttl: STEP_UP_TTL)
    return unless current_resource

    step_up = recent_social_auth_step_up(ttl: ttl)
    return if step_up.satisfied?

    # Emit the binding breakdown (booleans + the required scope only -- never the
    # token value or other PII) so operators can tell *why* the step-up was
    # rejected: expired vs. wrong session/token vs. purpose/audience mismatch.
    # A scope/aal/method mismatch shows up as usable_token=true with every
    # *_bound=true yet satisfied=false.
    Rails.logger.info(
      Jit::LogEvent.format(
        "social_auth.step_up_required",
        user_id: current_resource.id,
        last_step_up_at: step_up.satisfied_at&.iso8601,
        required_within: Integer(ttl.to_s, 10),
        required_scope: SOCIAL_LINK_SCOPE,
        usable_token: step_up.usable_token?,
        session_bound: step_up.session_bound,
        token_bound: step_up.token_bound,
        purpose_bound: step_up.purpose_bound,
        audience_bound: step_up.audience_bound,
      ),
    )
    raise SocialAuth::StepUpRequiredError.new("errors.social_auth.step_up_required")
  end

  def recent_social_auth_step_up(ttl:)
    token = social_auth_current_session_token
    StepUp::Resolver.call(
      token: token,
      requirement: social_auth_step_up_requirement(token, ttl: ttl),
    )
  end

  def social_auth_step_up_requirement(token, ttl:)
    StepUp::Requirement.new(
      scope: SOCIAL_LINK_SCOPE,
      session_binding: token&.public_id,
      token_binding: token&.public_id,
      ttl: ttl,
      purpose: :step_up,
      audience: social_auth_step_up_audience,
    )
  end

  def social_auth_current_session_token
    return current_session_token if respond_to?(:current_session_token, true)
    return nil unless respond_to?(:current_session_public_id, true) && respond_to?(:token_class, true)

    public_id = current_session_public_id
    return nil if public_id.blank?

    token_class.find_by(public_id: public_id)
  end

  def social_auth_step_up_audience
    step_up_audience if respond_to?(:step_up_audience, true)
  end

  def process_social_auth_callback
    auth_hash = omniauth_auth_hash
    intent = current_social_auth_intent
    pt = current_social_auth_pt
    entry = current_social_auth_entry
    authorize_social_auth_link!(social_auth_user) if intent == "link"

    result =
      if social_ceremony_grant_token.present? && social_ceremony_grant_operation == "link"
        process_social_ceremony_link_callback(auth_hash)
      elsif social_ceremony_grant_token.present? && social_ceremony_grant_operation == "login" &&
          acme_social_login_completion_supported?(auth_hash)
        process_social_ceremony_login_callback(auth_hash)
      else
        reject_grantless_app_social_link!(intent)
        reject_grantless_established_social_login!(auth_hash, intent)
        # Compatibility entry only. acme/www owns grant-backed social link authority and
        # established-account social login; unknown signup remains legacy for now.
        SocialAuthService.handle_callback(
          auth_hash: auth_hash,
          current_client: social_auth_user,
          intent: intent,
          sign_up_entry: intent == "login",
        )
      end
    result[:pt] = pt if pt.present?
    result[:entry] = entry if entry.present?

    clear_social_auth_intent!
    result
  end

  def reject_grantless_established_social_login!(auth_hash, intent)
    return unless intent.to_s == "login"
    return if social_ceremony_grant_token.present?
    return unless acme_social_login_completion_supported?(auth_hash)

    raise SocialAuth::UnauthorizedError.new("errors.social_auth.invalid_intent")
  end

  # App social link final commit is acme authority: it must flow through an
  # acme-issued ceremony grant and complete on acme. A grantless "link"
  # callback (including the auto-link path where an already-signed-in user
  # re-authenticates with a provider) must never reach the sign-side inline
  # commit in SocialAuthService. Reject it symmetrically with grantless
  # established social login so sign cannot create or mutate a social link.
  def reject_grantless_app_social_link!(intent)
    return unless intent.to_s == "link"
    return if social_ceremony_grant_token.present?

    raise SocialAuth::UnauthorizedError.new("errors.social_auth.invalid_intent")
  end

  def process_social_ceremony_link_callback(auth_hash)
    result_token = Identity::SocialCeremony::ResultIssuer.issue!(
      grant_token: social_ceremony_grant_token,
      auth_hash: auth_hash,
      surface: "app",
      actor_ref: social_auth_user.public_id,
      session_ref: current_session_public_id,
      operation: "link",
      challenge_id: extract_callback_state,
    )
    clear_social_auth_intent!
    render(
      "sign/shared/social_completion",
      locals: {
        completion_url: completion_acme_app_social_authentication_url(
          provider: auth_hash["provider"] || auth_hash[:provider],
          host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
        ),
        result_token: result_token,
        ri: params[:ri],
      },
      layout: false,
    )
    { user: nil, identity: nil, jwt_payload: {}, existing_account: nil, social_completion_rendered: true }
  end

  def process_social_ceremony_login_callback(auth_hash)
    grant = social_ceremony_grant
    result_token = Identity::SocialCeremony::ResultIssuer.issue!(
      grant_token: social_ceremony_grant_token,
      auth_hash: auth_hash,
      surface: "app",
      actor_ref: grant["actor_ref"],
      session_ref: grant["session_ref"],
      operation: "login",
      challenge_id: extract_callback_state,
    )
    clear_social_auth_intent!
    render(
      "sign/shared/social_completion",
      locals: {
        completion_url: completion_acme_app_social_authentication_url(
          provider: auth_hash["provider"] || auth_hash[:provider],
          host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
        ),
        result_token: result_token,
        ri: params[:ri],
      },
      layout: false,
    )
    { user: nil, identity: nil, jwt_payload: {}, existing_account: nil, social_completion_rendered: true }
  end

  # Whether a callback identity is an *established / completed* account that must
  # complete login through acme rather than the bounded-legacy sign-side signup
  # path.
  #
  # Bounded legacy: "completed account" is currently approximated by
  # birthdate-present, because birthdate is the final required checkpoint of the
  # client sign-up flow (an account that has it has finished signup). This is a
  # heuristic, not a status check; it is intentionally conservative so that only
  # accounts that have clearly finished signup are routed to (and, when grantless,
  # rejected by) the acme-owned established-login path. Unknown / incomplete
  # accounts remain on the compatibility signup path. If account completeness
  # gains a first-class status predicate, replace this with that predicate.
  def acme_social_login_completion_supported?(auth_hash)
    identity = social_auth_identity_for_callback(auth_hash)

    identity&.user&.birthdate.present?
  end

  def social_auth_identity_for_callback(auth_hash)
    return nil if auth_hash.blank?

    provider = auth_hash["provider"] || auth_hash[:provider]
    uid = SocialAuth::UidExtractor.call(auth_hash: auth_hash)
    return nil if provider.blank? || uid.blank?

    SocialIdentifiable.model_for_provider(provider).find_by(uid: uid, provider: provider)
  rescue SocialAuth::BaseError, ArgumentError
    nil
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
    return nil unless intent == "link"

    user_id = session[SOCIAL_USER_ID_SESSION_KEY].presence
    return nil if user_id.blank?

    @social_auth_user ||=
      begin
        klass = respond_to?(:resource_class, true) ? resource_class : Client
        klass.find_by(id: user_id)
      end
  end

  def authorize_social_auth_link!(resource)
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.not_logged_in") unless resource
    return if social_auth_link_allowed?(resource)

    raise SocialAuth::UnauthorizedError.new("errors.social_auth.not_logged_in")
  end

  def store_social_ceremony_grant!(token)
    grant = Identity::SocialCeremony::Grant.decode(
      token.to_s,
      issuer_id: Identity::SocialCeremony::Contract.acme_issuer_id("app"),
    )
    unless %w(link login).include?(grant["operation"].to_s)
      raise SocialAuth::UnauthorizedError.new("errors.social_auth.invalid_intent")
    end

    if grant["operation"].to_s == "link"
      raise SocialAuth::UnauthorizedError.new("errors.social_auth.user_changed") unless grant["actor_ref"].to_s ==
        current_resource&.public_id.to_s
      raise SocialAuth::UnauthorizedError.new("errors.social_auth.user_changed") unless grant["session_ref"].to_s ==
        current_session_public_id.to_s
    end

    session[SOCIAL_CEREMONY_GRANT_SESSION_KEY] = grant["transaction_id"].to_s
  rescue Identity::SocialCeremony::Error
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.invalid_intent")
  end

  def social_ceremony_grant_token
    raw_value = session[SOCIAL_CEREMONY_GRANT_SESSION_KEY].presence
    return nil if raw_value.blank?

    return raw_value if raw_value.include?(".")

    transaction = Identity::SocialCeremony::ReplayStore.for("app").find_transaction!(raw_value)
    Identity::SocialCeremony::Grant.issue(
      transaction.grant_claims,
      issuer_id: Identity::SocialCeremony::Contract.acme_issuer_id("app"),
    )
  rescue Identity::SocialCeremony::Error
    nil
  end

  def social_ceremony_grant
    @social_ceremony_grant ||= Identity::SocialCeremony::Grant.decode(
      social_ceremony_grant_token.to_s,
      issuer_id: Identity::SocialCeremony::Contract.acme_issuer_id("app"),
    )
  end

  def social_ceremony_grant_operation
    social_ceremony_grant["operation"].to_s
  rescue Identity::SocialCeremony::Error
    nil
  end

  def social_auth_authorization_resource
    return current_resource if respond_to?(:current_resource, true) && current_resource.present?
    return current_client if respond_to?(:current_client, true) && current_client.present?
    return current_operator if respond_to?(:current_operator, true) && current_operator.present?
    return current_visitor if respond_to?(:current_visitor, true) && current_visitor.present?

    nil
  end

  def social_auth_link_allowed?(resource)
    return allowed_to?(:update?, resource, context: { user: resource }) if respond_to?(:allowed_to?, true)

    policy_class =
      case resource
      when Client
        ClientPolicy
      when Operator
        OperatorPolicy
      end
    return false unless policy_class

    policy_class.new(resource, user: resource).apply(:update?)
  end

  def handle_social_auth_error(error)
    intent = @social_auth_intent_snapshot || current_social_auth_intent
    provider = @social_auth_provider_snapshot || omniauth_provider

    Rails.logger.info(
      Jit::LogEvent.format(
        "social_auth.error",
        error_class: error.class.name,
        error_message: error.message,
        status_code: error.status_code,
      ),
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

    Rails.logger.info(
      Jit::LogEvent.format(
        "social_auth.record_not_unique",
        error_message: error.message,
      ),
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
    respond_to?(:new_sign_app_sign_in_path) ? new_sign_app_sign_in_path : "/"
  end

  # Override this method to customize the success redirect path
  def social_auth_success_redirect_path
    respond_to?(:sign_app_root_path) ? sign_app_root_path : "/"
  end

  def validate_intent_ttl!(provider)
    started_at = session[SOCIAL_STARTED_AT_SESSION_KEY]
    return if started_at.blank?
    return if Time.current <= Time.zone.at(Integer(started_at.to_s, 10)) + STATE_TTL

    Rails.logger.info(
      Jit::LogEvent.format(
        "social_auth.intent_expired",
        provider: provider,
        started_at: started_at,
      ),
    )
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.state_expired")
  end

  def validate_user_consistency!(intent)
    return unless intent == "link"

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
    return social_auth_failure_redirect_path unless intent == "link"

    provider_from_path = request.path.to_s.split("/auth/").last&.split("/")&.first
    provider = provider.presence || session[SOCIAL_PROVIDER_SESSION_KEY] || params[:provider] || provider_from_path

    if provider.to_s == "apple"
      return sign_app_settings_apple_path if respond_to?(:sign_app_settings_apple_path, true)
      if Rails.application.routes.url_helpers.respond_to?(:sign_app_settings_apple_path)
        return Rails.application.routes.url_helpers.sign_app_settings_apple_path
      end
    end

    return sign_app_settings_path if respond_to?(:sign_app_settings_path, true)
    if Rails.application.routes.url_helpers.respond_to?(:sign_app_settings_path)
      return Rails.application.routes.url_helpers.sign_app_settings_path
    end

    social_auth_failure_redirect_path
  end
end
