# typed: false
# frozen_string_literal: true

# Handles OAuth social authentication callback processing.
# Supports login, link, and reauth intents.
#
# Usage:
#   result = SocialAuthService.handle_callback(
#     auth_hash: request.env["omniauth.auth"],
#     current_user: current_user,
#     intent: "login"
#   )
#   # => { user: User, identity: UserSocialGoogle, jwt_payload: {...} }
#
#   SocialAuthService.unlink(provider: "google", user: user)
#
class SocialAuthService
  VALID_INTENTS = %w(login link reauth).freeze
  ALLOWED_ID_TOKEN_ALGORITHMS = %w(RS256 ES256).freeze

  class << self
    def handle_callback(auth_hash:, current_user:, intent:)
      new(auth_hash:, current_user:, intent:).handle_callback
    end

    def unlink(provider:, user:)
      new(auth_hash: nil, current_user: user, intent: nil).unlink(provider)
    end
  end

  def initialize(auth_hash:, current_user:, intent:)
    @auth_hash = auth_hash
    @current_user = current_user
    @intent = intent&.to_s
  end

  def handle_callback
    Rails.logger.debug do
      "[SocialAuth] handle_callback started - intent: #{@intent.inspect}, current_user: #{@current_user&.id}"
    end

    validate_intent! if @intent.present?
    validate_auth_hash!

    provider = extract_provider
    uid = extract_uid
    identity_class = SocialIdentifiable.model_for_provider(provider)
    ensure_identity_status!(identity_class)

    Rails.logger.debug do
      "[SocialAuth] Extracted - provider: #{provider}, uid: #{uid&.first(8)}***, " \
        "identity_class: #{identity_class.name}"
    end

    result =
      PrincipalRecord.transaction do
        case @intent
        when "login", nil
          Rails.logger.debug { "[SocialAuth] Processing login intent" }
          handle_login(identity_class, provider, uid)
        when "link"
          Rails.logger.debug { "[SocialAuth] Processing link intent" }
          handle_link(identity_class, provider, uid)
        when "reauth"
          Rails.logger.debug { "[SocialAuth] Processing reauth intent" }
          handle_reauth(identity_class, provider, uid)
        end
      end

    Rails.logger.debug do
      "[SocialAuth] handle_callback completed - user_id: #{result[:user]&.id}, " \
        "identity_id: #{result[:identity]&.id}"
    end
    result
  end

  def unlink(provider)
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.not_logged_in") unless @current_user

    identity_class = SocialIdentifiable.model_for_provider(provider)
    identity = identity_for_user(identity_class, provider)

    return { success: true, provider: provider, already_unlinked: true } unless identity

    PrincipalRecord.transaction do
      # Lock the user to prevent race conditions
      @current_user.lock!

      # Check if this is the last authentication method
      if identity.active? && !@current_user.login_methods_remaining?(excluding_provider: provider)
        raise SocialAuth::LastIdentityError.new("errors.social_auth.insufficient_login_methods")
      end

      create_social_unlink_audit!(identity, provider)
      identity.destroy!

      Rails.event.notify(
        "social_auth.unlinked",
        user_id: @current_user.id,
        provider: provider,
      )
    end

    { success: true, provider: provider }
  end

  private

  def validate_intent!
    return if VALID_INTENTS.include?(@intent)

    raise SocialAuth::UnauthorizedError.new(
      "errors.social_auth.invalid_intent",
      intent: @intent,
    )
  end

  def validate_auth_hash!
    raise SocialAuth::ProviderError.new("errors.social_auth.missing_auth_hash") unless @auth_hash
  end

  def extract_provider
    provider = @auth_hash["provider"] || @auth_hash[:provider]
    raise SocialAuth::ProviderError.new("errors.social_auth.missing_provider") if provider.blank?

    provider.to_s
  end

  def extract_uid
    uid = @auth_hash["uid"] || @auth_hash[:uid]

    # Fallback chain for uid extraction (especially important for Apple)
    if uid.blank?
      # Try extra.raw_info.sub (standard OIDC)
      raw_info = @auth_hash.dig("extra", "raw_info") || @auth_hash.dig(:extra, :raw_info)
      uid = raw_info&.dig("sub") || raw_info&.dig(:sub)
    end

    if uid.blank?
      # Try id_info.sub (omniauth-apple specific)
      id_info = @auth_hash.dig("extra", "id_info") || @auth_hash.dig(:extra, :id_info)
      uid = id_info&.dig("sub") || id_info&.dig(:sub)
    end

    if uid.blank?
      # Last resort: decode id_token directly (Apple)
      uid = extract_uid_from_id_token
    end

    raise SocialAuth::ProviderError.new("errors.social_auth.missing_uid") if uid.blank?

    uid.to_s
  end

  # Extract uid (sub claim) from Apple's id_token by decoding JWT payload
  # This is a fallback when omniauth-apple doesn't populate uid correctly
  def extract_uid_from_id_token
    id_token = @auth_hash.dig("credentials", "id_token")
    id_token ||= @auth_hash.dig(:credentials, :id_token)
    return nil if id_token.blank?

    # Guard against alg:none forgery as defense in depth.
    # omniauth-apple already verified the token, but we explicitly reject
    # disallowed algorithms before decoding.
    header_segment = id_token.split(".").first
    padding = "=" * ((4 - (header_segment.length % 4)) % 4)
    header_json = Base64.urlsafe_decode64(header_segment + padding)
    alg = JSON.parse(header_json)["alg"]
    unless ALLOWED_ID_TOKEN_ALGORITHMS.include?(alg)
      Rails.logger.warn("[SocialAuth] Rejected id_token with disallowed algorithm: #{alg.inspect}")
      return nil
    end

    # Decode JWT without signature verification (we just need the sub claim).
    # The token has already been verified by omniauth-apple.
    payload = JWT.decode(id_token, nil, false, algorithms: ALLOWED_ID_TOKEN_ALGORITHMS).first
    uid = payload["sub"]
    Rails.logger.debug { "[SocialAuth] Extracted uid from id_token: #{uid&.first(8)}***" }
    uid
  rescue JWT::DecodeError, JSON::ParserError, ArgumentError => e
    Rails.logger.warn("[SocialAuth] Failed to decode id_token: #{e.message}")
    nil
  end

  # Intent: login (or nil for backward compatibility)
  # - If identity exists with user -> sign in
  # - If identity exists without user -> create user and sign in
  # - If identity doesn't exist -> create identity and user, sign in
  def handle_login(identity_class, provider, uid)
    identity = identity_class.lock.find_by(uid: uid, provider: provider)
    Rails.logger.debug { "[SocialAuth] handle_login - identity found: #{identity.present?}" }

    if identity
      # Existing identity
      user = identity.user
      Rails.logger.debug do
        "[SocialAuth] Existing identity - user_id: #{user&.id}, orphaned: #{user.nil?}"
      end

      unless user
        # Orphaned identity - create user
        Rails.logger.debug { "[SocialAuth] Creating user for orphaned identity" }
        user = create_user_for_identity(identity, identity_class, provider)
      end

      identity.update_from_auth_hash!(@auth_hash)
      Rails.logger.debug { "[SocialAuth] Identity updated from auth_hash" }
      build_result(user, identity, reauthenticated: false, existing_account: true)
    else
      # New identity - create user and identity
      Rails.logger.debug { "[SocialAuth] Creating new user and identity" }
      user = build_login_user
      identity = build_identity_for_user(identity_class, user, provider, uid)

      persist_user!(user, context: "login_new_identity")
      identity.save!
      identity.touch_authenticated!
      create_social_signup_audit!(user, provider)
      Rails.logger.debug { "[SocialAuth] New user created - user_id: #{user.id}" }

      build_result(user, identity, reauthenticated: false, existing_account: false)
    end
  rescue ActiveRecord::RecordNotUnique => e
    # Race condition: identity was created between check and insert
    Rails.event.notify(
      "social_auth.race_condition",
      provider: provider,
      uid: uid,
      error: e.message,
    )
    raise SocialAuth::ConflictError.new("errors.social_auth.identity_conflict")
  end

  # Intent: link
  # - Requires current_user
  # - If identity exists and belongs to another user -> 409 Conflict
  # - If identity exists and belongs to current_user -> update and return (reactivate if REVOKED)
  # - If identity doesn't exist -> create and link to current_user
  def handle_link(identity_class, provider, uid)
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.not_logged_in") unless @current_user

    Rails.logger.debug { "[SocialAuth] handle_link - current_user_id: #{@current_user.id}" }

    # Check if user already has this provider linked
    existing_for_user = identity_for_user(identity_class, provider)
    Rails.logger.debug do
      "[SocialAuth] User already has provider: #{existing_for_user.present?}"
    end

    if existing_for_user
      was_active = existing_for_user.active?

      # User already has this provider - update and ensure it's ACTIVE
      existing_for_user.update_from_auth_hash!(@auth_hash)

      # Reactivate if it was REVOKED
      active_status =
        case identity_class.name
        when "UserSocialGoogle"
          UserSocialGoogleStatus::ACTIVE
        when "UserSocialApple"
          UserSocialAppleStatus::ACTIVE
        end

      existing_for_user.update!(identity_class.status_column => active_status)
      create_social_link_audit!(existing_for_user, provider) unless was_active
      Rails.logger.debug { "[SocialAuth] Reactivated existing identity" }
      return build_result(@current_user, existing_for_user, reauthenticated: false)
    end

    identity = identity_class.lock.find_by(uid: uid, provider: provider)
    Rails.logger.debug do
      "[SocialAuth] Identity with uid exists: #{identity.present?}, " \
        "belongs_to_current_user: #{identity&.user_id == @current_user.id}"
    end

    if identity
      # Identity exists
      if identity.user_id != @current_user.id
        # Belongs to another user - conflict
        Rails.logger.debug do
          "[SocialAuth] Conflict - identity belongs to another user: #{identity.user_id}"
        end
        raise SocialAuth::ConflictError.new(
          "errors.social_auth.linked_to_another_user",
          provider: SocialIdentifiable.normalize_provider(provider),
        )
      end

      # Belongs to current user (shouldn't happen due to unique constraint, but handle it)
      Rails.logger.debug { "[SocialAuth] Identity already belongs to current user, updating" }
      was_active = identity.active?
      identity.update_from_auth_hash!(@auth_hash)
      create_social_link_audit!(identity, provider) unless was_active
      build_result(@current_user, identity, reauthenticated: false)
    else
      # Create new identity for current user
      Rails.logger.debug { "[SocialAuth] Creating new identity for current user" }
      identity = build_identity_for_user(identity_class, @current_user, provider, uid)
      identity.save!
      identity.touch_authenticated!
      create_social_link_audit!(identity, provider)

      Rails.event.notify(
        "social_auth.linked",
        user_id: @current_user.id,
        provider: provider,
      )

      Rails.logger.debug { "[SocialAuth] Successfully linked new identity" }
      build_result(@current_user, identity, reauthenticated: false)
    end
  rescue ActiveRecord::RecordNotUnique => e
    Rails.event.notify(
      "social_auth.link_race_condition",
      user_id: @current_user.id,
      provider: provider,
      uid: uid,
      error: e.message,
    )
    raise SocialAuth::ConflictError.new("errors.social_auth.identity_conflict")
  end

  # Intent: reauth
  # - Requires current_user
  # - Identity must belong to current_user
  # - Updates user.last_reauth_at
  # - JWT payload includes reauthenticated_at
  def handle_reauth(identity_class, provider, uid)
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.not_logged_in") unless @current_user

    Rails.logger.debug { "[SocialAuth] handle_reauth - current_user_id: #{@current_user.id}" }

    identity = identity_class.lock.find_by(uid: uid, provider: provider)
    Rails.logger.debug do
      "[SocialAuth] Identity found: #{identity.present?}, " \
        "belongs_to_current_user: #{identity&.user_id == @current_user.id}"
    end

    unless identity && identity.user_id == @current_user.id
      Rails.logger.debug { "[SocialAuth] Reauth failed - identity mismatch" }
      raise SocialAuth::UnauthorizedError.new(
        "errors.social_auth.reauth_identity_mismatch",
        provider: SocialIdentifiable.normalize_provider(provider),
      )
    end

    now = Time.current
    identity.update_from_auth_hash!(@auth_hash)
    @current_user.update!(last_reauth_at: now)
    Rails.logger.debug { "[SocialAuth] Reauth successful - last_reauth_at updated" }

    Rails.event.notify(
      "social_auth.reauthenticated",
      user_id: @current_user.id,
      provider: provider,
    )

    build_result(@current_user, identity, reauthenticated: true, reauth_at: now)
  end

  def create_user_for_identity(identity, identity_class, provider)
    user = build_login_user
    assign_identity_to_user(user, identity, identity_class, provider)
    persist_user!(user, context: "login_orphaned_identity")
    identity.update!(user: user)
    user
  end

  def build_login_user
    user = User.new
    ensure_user_status(user)
    ensure_user_visibility(user)
    ensure_user_multi_factor(user)
    user
  end

  def ensure_user_status(user)
    # If status is unset or defaulted to NOTHING, set it to UNVERIFIED_WITH_SIGN_UP for social sign-up.
    if user.status_id.present? && user.status_id != UserStatus::NOTHING
      return
    end

    status = ensure_user_status_record(UserStatus::UNVERIFIED_WITH_SIGN_UP, "UNVERIFIED_WITH_SIGN_UP") ||
      ensure_user_status_record(UserStatus::NOTHING, "NEYO") ||
      UserStatus.first

    if status.present?
      user.status_id = status.id
    else
      Rails.logger.error("[SocialAuth] User status missing - unable to assign default status")
    end
  end

  def ensure_user_status_record(id, code)
    ensure_reference_record!(UserStatus, id, code)
  end

  def ensure_user_visibility(user)
    visibility = ensure_user_visibility_record(user.visibility_id, "STAFF") ||
      ensure_user_visibility_record(UserVisibility::STAFF, "STAFF") ||
      ensure_user_visibility_record(UserVisibility::USER, "USER") ||
      UserVisibility.first

    if visibility.present?
      user.visibility_id = visibility.id
    else
      Rails.logger.error("[SocialAuth] User visibility missing - unable to assign default visibility")
    end
  end

  def ensure_user_visibility_record(id, code)
    return nil if id.blank?

    ensure_reference_record!(UserVisibility, id, code)
  end

  def ensure_user_multi_factor(user)
    multi_factor = ensure_user_multi_factor_record(user.multi_factor_id) ||
      ensure_user_multi_factor_record(UserMultiFactor::NOTHING) ||
      UserMultiFactor.first

    if multi_factor.present?
      user.multi_factor_id = multi_factor.id
    else
      Rails.logger.error("[SocialAuth] User multi factor missing - unable to assign default multi factor")
    end
  end

  def ensure_user_multi_factor_record(id)
    return nil if id.blank?

    ensure_reference_record!(UserMultiFactor, id, nil)
  end

  def ensure_identity_status!(identity_class)
    status_class = identity_class.status_class if identity_class.respond_to?(:status_class)
    return unless status_class

    ensure_reference_record!(status_class, status_class::ACTIVE, "ACTIVE")
  end

  def ensure_reference_record!(model, id, code)
    PrincipalRecord.connected_to(role: :writing) do
      attributes = { id: id }
      attributes[:code] = code if model.column_names.include?("code")

      model.find_or_create_by!(id: id) do |record|
        attributes.each do |attribute, value|
          record.public_send("#{attribute}=", value)
        end
      end
    end
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.warn(
      "[SocialAuth] Failed to ensure reference record - model: #{model.name}, id: #{id.inspect}, " \
      "error: #{e.class.name}: #{e.message}",
    )
    nil
  end

  def persist_user!(user, context:)
    user.save!
    user.create_user_account! unless user.user_account
  rescue ActiveRecord::RecordInvalid => e
    log_user_status_error(user, e, context: context)
    raise SocialAuth::ProviderError.new("errors.social_auth.provider_error")
  end

  def log_user_status_error(user, error, context:)
    details = user.errors.details.slice(:user_status, :status_id)
    Rails.logger.warn(
      "[SocialAuth] User creation failed (#{context}) - " \
      "status_id: #{user.status_id.inspect}, errors: #{details.inspect}, message: #{error.message}",
    )
  end

  def build_identity_for_user(identity_class, user, provider, uid)
    identity = identity_class.new(
      uid: uid,
      provider: provider,
      token: @auth_hash.dig("credentials", "token") || @auth_hash.dig(:credentials, :token) || "",
      refresh_token: @auth_hash.dig(
        "credentials",
        "refresh_token",
      ) || @auth_hash.dig(:credentials, :refresh_token) || "",
      expires_at: @auth_hash.dig(
        "credentials",
        "expires_at",
      ) || @auth_hash.dig(:credentials, :expires_at) || 0,
    )
    assign_identity_to_user(user, identity, identity_class, provider)
    identity
  end

  def assign_identity_to_user(user, identity, identity_class, provider)
    case identity_class.name
    when "UserSocialGoogle"
      user.user_social_google = identity
      identity.user = user
    when "UserSocialApple"
      user.user_social_apple = identity
      identity.user = user
    end
  end

  def identity_for_user(identity_class, provider)
    case identity_class.name
    when "UserSocialGoogle"
      @current_user.user_social_google
    when "UserSocialApple"
      @current_user.user_social_apple
    end
  end

  def create_audit_event!(event_id, subject:)
    ChronicleRecord.connected_to(role: :writing) do
      UserChronicleEvent.find_or_create_by!(id: event_id)
      UserChronicleLevel.find_or_create_by!(id: UserChronicleLevel::NOTHING)
    end

    UserChronicle.create!(
      actor_type: "User",
      actor_id: @current_user.id,
      event_id: event_id,
      subject_id: subject.id.to_s,
      subject_type: subject.class.name,
      occurred_at: Time.current,
    )
  end

  def create_social_signup_audit!(user, provider)
    event_id = social_signup_event_id(provider)
    return unless event_id

    ChronicleRecord.connected_to(role: :writing) do
      UserChronicleEvent.find_or_create_by!(id: event_id)
      UserChronicleLevel.find_or_create_by!(id: UserChronicleLevel::NOTHING)
    end

    UserChronicle.create!(
      actor_type: "User",
      actor_id: user.id,
      event_id: event_id,
      level_id: UserChronicleLevel::NOTHING,
      subject_id: user.id.to_s,
      subject_type: "User",
      occurred_at: Time.current,
      context: {
        auth_method: "social",
        provider: SocialIdentifiable.normalize_provider(provider),
      },
    )
  end

  def create_social_link_audit!(identity, provider)
    create_user_social_audit!(
      event_id: UserChronicleEvent::SOCIAL_LINKED,
      provider: provider,
      subject: @current_user,
      extra_context: { social_identity_type: identity.class.name },
    )
  end

  def create_social_unlink_audit!(identity, provider)
    create_user_social_audit!(
      event_id: UserChronicleEvent::SOCIAL_UNLINKED,
      provider: provider,
      subject: @current_user,
      extra_context: { social_identity_type: identity.class.name },
    )
  end

  def create_user_social_audit!(event_id:, provider:, subject:, extra_context: {})
    ChronicleRecord.connected_to(role: :writing) do
      UserChronicleEvent.find_or_create_by!(id: event_id)
      UserChronicleLevel.find_or_create_by!(id: UserChronicleLevel::NOTHING)
    end

    UserChronicle.create!(
      actor_type: "User",
      actor_id: subject.id,
      event_id: event_id,
      level_id: UserChronicleLevel::NOTHING,
      subject_id: subject.id.to_s,
      subject_type: "User",
      occurred_at: Time.current,
      context: {
        auth_method: "social",
        provider: SocialIdentifiable.normalize_provider(provider),
      }.merge(extra_context),
    )
  end

  def social_signup_event_id(provider)
    case SocialIdentifiable.normalize_provider(provider)
    when "google"
      UserChronicleEvent::SIGNED_UP_WITH_GOOGLE
    when "apple"
      UserChronicleEvent::SIGNED_UP_WITH_APPLE
    end
  end

  def last_authentication_method?(excluding_provider: nil)
    !@current_user.login_methods_remaining?(excluding_provider: excluding_provider)
  end

  def build_result(user, identity, reauthenticated:, reauth_at: nil, existing_account: nil)
    jwt_payload = { user_id: user.id }
    jwt_payload[:reauthenticated_at] = reauth_at.iso8601 if reauthenticated && reauth_at

    {
      user: user,
      identity: identity,
      jwt_payload: jwt_payload,
      reauthenticated: reauthenticated,
      existing_account: existing_account,
    }
  end
end
