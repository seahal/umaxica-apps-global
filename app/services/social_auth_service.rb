# typed: false
# frozen_string_literal: true

# Handles OAuth social authentication callback processing.
# Supports login and link intents. Social authentication is AAL1 and must not satisfy AAL2 step-up.
#
# Usage:
#   result = SocialAuthService.handle_callback(
#     auth_hash: request.env["omniauth.auth"],
#     current_client: current_client,
#     intent: "login"
#   )
#   # => { user: Client, identity: ClientGoogleIdentity, jwt_payload: {...} }
#
#   SocialAuthService.unlink(provider: "google", client: client)
#
class SocialAuthService
  VALID_INTENTS = %w(login link).freeze

  class << self
    def handle_callback(auth_hash:, current_client: nil, current_user: nil, intent:, sign_up_entry: false)
      new(
        auth_hash:,
        current_client: current_client || current_user,
        intent:,
        sign_up_entry: sign_up_entry,
      ).handle_callback
    end

    def unlink(provider:, client: nil, user: nil)
      new(auth_hash: nil, current_client: client || user, intent: nil).unlink(provider)
    end
  end

  def initialize(auth_hash:, current_client: nil, current_user: nil, intent:, sign_up_entry: false)
    @auth_hash = auth_hash
    @current_client = current_client || current_user
    @intent = intent&.to_s
    @sign_up_entry = sign_up_entry
  end

  def handle_callback
    Rails.logger.debug do
      "[SocialAuth] handle_callback started - intent: #{@intent.inspect}, current_client: #{@current_client&.id}"
    end

    validate_intent! if @intent.present?
    validate_auth_hash!

    provider = extract_provider
    validate_app_social_provider!(provider)
    uid = extract_uid
    identity_class = SocialIdentifiable.model_for_provider(provider)
    ensure_identity_status!(identity_class)

    Rails.logger.debug do
      "[SocialAuth] Extracted - provider: #{provider}, uid: #{uid&.first(8)}***, " \
        "identity_class: #{identity_class.name}"
    end

    result =
      AppPrincipalRecord.transaction do
        case @intent
        when "login", nil
          Rails.logger.debug { "[SocialAuth] Processing login intent" }
          handle_login(identity_class, provider, uid)
        when "link"
          Rails.logger.debug { "[SocialAuth] Processing link intent" }
          handle_link(identity_class, provider, uid)
        end
      end

    Rails.logger.debug do
      "[SocialAuth] handle_callback completed - user_id: #{result[:user]&.id}, " \
        "identity_id: #{result[:identity]&.id}"
    end
    result
  end

  def unlink(provider)
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.not_logged_in") unless @current_client

    identity_class = SocialIdentifiable.model_for_provider(provider)
    identity = identity_for_user(identity_class, provider)

    return { success: true, provider: provider, already_unlinked: true } unless identity

    AppPrincipalRecord.transaction do
      # Lock the user to prevent race conditions
      @current_client.lock!

      # Check if this is the last authentication method
      if identity.active? && !@current_client.social_unlink_methods_remaining?(excluding_provider: provider)
        raise SocialAuth::LastIdentityError.new("errors.social_auth.insufficient_login_methods")
      end

      create_social_unlink_audit!(identity, provider)
      identity.destroy!

      Rails.logger.info(
        Jit::LogEvent.format(
          "social_auth.unlinked",
          user_id: @current_client.id,
          provider: provider,
        ),
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

  def validate_app_social_provider!(provider)
    return unless provider.to_s == "google_org"

    raise SocialAuth::ProviderError.new("errors.social_auth.provider_error")
  end

  def extract_uid
    SocialAuth::UidExtractor.call(auth_hash: @auth_hash)
  end

  # Intent: login (or nil for backward compatibility)
  # - If identity exists with user -> sign in
  # - If identity exists without user -> create user and sign in
  # - If identity doesn't exist -> create identity and user, sign in
  def handle_login(identity_class, provider, uid)
    SocialAuth::LoginHandler.call(
      auth_hash: @auth_hash,
      identity_class: identity_class,
      provider: provider,
      uid: uid,
      sign_up_entry: @sign_up_entry || @intent == "login",
    )
  end

  # Intent: link
  # - Requires current_client
  # - If identity exists and belongs to another user -> 409 Conflict
  # - If identity exists and belongs to current_client -> update and return (reactivate if REVOKED)
  # - If identity doesn't exist -> create and link to current_client
  def handle_link(identity_class, provider, uid)
    SocialAuth::LinkHandler.call(
      auth_hash: @auth_hash,
      current_client: @current_client,
      identity_class: identity_class,
      provider: provider,
      uid: uid,
    )
  end

  def ensure_identity_status!(identity_class)
    status_class = identity_class.status_class if identity_class.respond_to?(:status_class)
    return unless status_class

    ensure_reference_record!(status_class, status_class::ACTIVE, "ACTIVE")
  end

  def ensure_reference_record!(model, id, code)
    AppPrincipalRecord.connected_to(role: :writing) do
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

  def same_social_identity?(identity, provider, uid)
    identity.uid.to_s == uid.to_s &&
      SocialIdentifiable.normalize_provider(identity.provider) == SocialIdentifiable.normalize_provider(provider)
  end

  def identity_for_user(identity_class, provider)
    case identity_class.name
    when "ClientGoogleIdentity"
      @current_client.user_google_identity
    when "ClientAppleIdentity"
      @current_client.user_apple_identity
    end
  end

  def create_audit_event!(event_id, subject:)
    ChronicleRecord.connected_to(role: :writing) do
      ClientChronicleEvent.find_or_create_by!(id: event_id)
      ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)
    end

    ClientChronicle.create!(
      actor_type: "Client",
      actor_id: @current_client.id,
      event_id: event_id,
      subject_id: subject.id.to_s,
      subject_type: subject.class.name,
      occurred_at: Time.current,
    )
  end

  def create_social_link_audit!(identity, provider)
    create_user_social_audit!(
      event_id: ClientChronicleEvent::SOCIAL_LINKED,
      provider: provider,
      subject: @current_client,
      extra_context: { social_identity_type: identity.class.name },
    )
  end

  def create_social_unlink_audit!(identity, provider)
    create_user_social_audit!(
      event_id: ClientChronicleEvent::SOCIAL_UNLINKED,
      provider: provider,
      subject: @current_client,
      extra_context: { social_identity_type: identity.class.name },
    )
  end

  def create_user_social_audit!(event_id:, provider:, subject:, extra_context: {})
    ChronicleRecord.connected_to(role: :writing) do
      ClientChronicleEvent.find_or_create_by!(id: event_id)
      ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)
    end

    ClientChronicle.create!(
      actor_type: "Client",
      actor_id: subject.id,
      event_id: event_id,
      level_id: ClientChronicleLevel::NOTHING,
      subject_id: subject.id.to_s,
      subject_type: "Client",
      occurred_at: Time.current,
      context: {
        auth_method: "social",
        provider: SocialIdentifiable.normalize_provider(provider),
      }.merge(extra_context),
    )
  end

  def last_authentication_method?(excluding_provider: nil)
    !@current_client.login_methods_remaining?(excluding_provider: excluding_provider)
  end
end
