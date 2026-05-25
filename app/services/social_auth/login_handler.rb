# typed: false
# frozen_string_literal: true

module SocialAuth
  # Handles social login and social sign-up from a verified provider identity.
  class LoginHandler
    def self.call(...)
      new(...).call
    end

    def initialize(auth_hash:, identity_class:, provider:, uid:, sign_up_entry: false)
      @auth_hash = auth_hash
      @identity_class = identity_class
      @provider = provider
      @uid = uid
      @sign_up_entry = sign_up_entry
    end

    def call
      identity = identity_class.lock.find_by(uid: uid, provider: provider)
      Rails.logger.debug { "[SocialAuth] handle_login - identity found: #{identity.present?}" }

      identity ? login_existing_identity(identity) : login_new_identity
    rescue ActiveRecord::RecordNotUnique => e
      Rails.logger.info(
        LogEvent.format(
          "social_auth.race_condition",
          provider: provider,
          uid: uid,
          error: e.message,
        ),
      )
      raise ConflictError.new("errors.social_auth.identity_conflict")
    end

    private

    attr_reader :auth_hash, :identity_class, :provider, :uid, :sign_up_entry

    def login_existing_identity(identity)
      user = identity.user
      existing_account = user.present?
      Rails.logger.debug do
        "[SocialAuth] Existing identity - user_id: #{user&.id}, orphaned: #{user.nil?}"
      end

      user ||= create_user_for_identity(identity)

      identity.update_from_auth_hash!(auth_hash)
      Rails.logger.debug { "[SocialAuth] Identity updated from auth_hash" }
      build_result(user, identity, existing_account: existing_account)
    end

    def login_new_identity
      Rails.logger.debug { "[SocialAuth] Creating new user and identity" }
      user = build_login_user

      persist_user!(user, context: "login_new_identity")
      identity = build_identity_for_user(user)
      identity.save!
      identity.touch_authenticated!
      # Chronicle write happens AFTER user/identity have been persisted.
      # If either save above raises, this line is unreachable and no
      # orphan SIGNED_UP_WITH_GOOGLE/SIGNED_UP_WITH_APPLE row is created.
      # See S-8.
      create_social_signup_audit(user) unless sign_up_entry
      Rails.logger.debug { "[SocialAuth] New user created - user_id: #{user.id}" }

      build_result(user, identity, existing_account: false)
    end

    def create_user_for_identity(identity)
      Rails.logger.debug { "[SocialAuth] Creating user for orphaned identity" }
      user = build_login_user
      persist_user!(user, context: "login_orphaned_identity")
      assign_identity_to_user(user, identity)
      identity.update!(user_id: user.id)
      user
    end

    def build_login_user
      user = Client.new
      ensure_user_status(user)
      ensure_user_visibility(user)
      ensure_user_multi_factor(user)
      ensure_user_multi_factor_status(user)
      user
    end

    def ensure_user_status(user)
      return if user.status_id.present? && user.status_id != ClientStatus::NOTHING

      status = ensure_user_status_record(ClientStatus::UNVERIFIED_WITH_SIGN_UP, "UNVERIFIED_WITH_SIGN_UP") ||
        ensure_user_status_record(ClientStatus::NOTHING, "NEYO") ||
        ClientStatus.first

      if status.present?
        user.status_id = status.id
      else
        Rails.logger.error(LogEvent.format("social_auth.default_reference.missing", reference: "user_status"))
      end
    end

    def ensure_user_status_record(id, code)
      ensure_reference_record!(ClientStatus, id, code)
    end

    def ensure_user_visibility(user)
      visibility = ensure_user_visibility_record(user.visibility_id, "STAFF") ||
        ensure_user_visibility_record(ClientVisibility::STAFF, "STAFF") ||
        ensure_user_visibility_record(ClientVisibility::USER, "USER") ||
        ClientVisibility.first

      if visibility.present?
        user.visibility_id = visibility.id
      else
        Rails.logger.error(LogEvent.format("social_auth.default_reference.missing", reference: "user_visibility"))
      end
    end

    def ensure_user_visibility_record(id, code)
      return nil if id.blank?

      ensure_reference_record!(ClientVisibility, id, code)
    end

    def ensure_user_multi_factor(user)
      multi_factor = ensure_user_multi_factor_record(user.multi_factor_id) ||
        ensure_user_multi_factor_record(ClientMultiFactor::NOTHING) ||
        ClientMultiFactor.first

      if multi_factor.present?
        user.multi_factor_id = multi_factor.id
      else
        Rails.logger.error(LogEvent.format("social_auth.default_reference.missing", reference: "user_multi_factor"))
      end
    end

    def ensure_user_multi_factor_record(id)
      return nil if id.blank?

      ensure_reference_record!(ClientMultiFactor, id, nil)
    end

    def ensure_user_multi_factor_status(user)
      status = ensure_user_multi_factor_status_record(user.multi_factor_status_id) ||
        ensure_user_multi_factor_status_record(ClientMultiFactorStatus::UNCONFIGURED) ||
        ClientMultiFactorStatus.first

      if status.present?
        user.multi_factor_status_id = status.id
      else
        Rails.logger.error(
          LogEvent.format(
            "social_auth.default_reference.missing",
            reference: "user_multi_factor_status",
          ),
        )
      end
    end

    def ensure_user_multi_factor_status_record(id)
      return nil if id.blank?

      ensure_reference_record!(ClientMultiFactorStatus, id, nil)
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

    def persist_user!(user, context:)
      user.save!
      user.create_rp_account! unless sign_up_entry || user.rp_account
    rescue ActiveRecord::RecordInvalid => e
      log_user_status_error(user, e, context: context)
      raise ProviderError.new("errors.social_auth.provider_error")
    end

    def log_user_status_error(user, error, context:)
      details = user.errors.details.slice(:user_status, :status_id)
      Rails.logger.warn(
        "[SocialAuth] User creation failed (#{context}) - " \
        "status_id: #{user.status_id.inspect}, errors: #{details.inspect}, message: #{error.message}",
      )
    end

    def build_identity_for_user(user)
      identity = identity_class.new(
        uid: uid,
        provider: provider,
        token: auth_hash.dig("credentials", "token") || auth_hash.dig(:credentials, :token) || "",
        refresh_token: auth_hash.dig("credentials", "refresh_token") ||
          auth_hash.dig(:credentials, :refresh_token) || "",
        expires_at: auth_hash.dig("credentials", "expires_at") || auth_hash.dig(:credentials, :expires_at) || 0,
      )
      assign_identity_to_user(user, identity)
      identity
    end

    def assign_identity_to_user(user, identity)
      case identity_class.name
      when "ClientSocialGoogle", "ClientSocialApple"
        identity.user_id = user.id
      end
    end

    def create_social_signup_audit(user)
      event_id = social_signup_event_id
      return unless event_id

      ChronicleRecord.connected_to(role: :writing) do
        ClientChronicleEvent.find_or_create_by!(id: event_id)
        ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)
      end

      ClientChronicle.create!(
        actor_type: "Client",
        actor_id: user.id,
        event_id: event_id,
        level_id: ClientChronicleLevel::NOTHING,
        subject_id: user.id.to_s,
        subject_type: "Client",
        occurred_at: Time.current,
        context: {
          auth_method: "social",
          provider: SocialIdentifiable.normalize_provider(provider),
        },
      )
    end

    def social_signup_event_id
      case SocialIdentifiable.normalize_provider(provider)
      when "google"
        ClientChronicleEvent::SIGNED_UP_WITH_GOOGLE
      when "apple"
        ClientChronicleEvent::SIGNED_UP_WITH_APPLE
      end
    end

    def build_result(user, identity, existing_account:)
      {
        user: user,
        identity: identity,
        jwt_payload: { user_id: user.id },
        step_up_authenticated: false,
        existing_account: existing_account,
      }
    end
  end
end
