# typed: false
# frozen_string_literal: true

class SocialAuthSignupFinalizer
  def self.call(...)
    new(...).call
  end

  def initialize(auth_hash:, birthdate:)
    @auth_hash = auth_hash
    @birthdate = birthdate
  end

  def call
    validate_auth_hash!

    AppPrincipalRecord.transaction do
      ensure_signup_reference_defaults!
      ensure_identity_status!
      existing_identity = identity_class.lock.find_by(uid: uid, provider: provider)
      raise SocialAuth::ProviderError.new("errors.social_auth.identity_conflict") if existing_identity&.user_id.present?

      user = build_user
      user.save!

      identity = existing_identity || identity_class.new(uid: uid, provider: provider)
      identity.assign_auth_credentials(auth_hash)
      identity.user = user
      identity.save!
      identity.touch_authenticated!

      { user: user, identity: identity }
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique => e
    Rails.logger.error(
      "SocialAuthSignupFinalizer failed: #{e.class}: #{e.message} " \
      "(record=#{e.respond_to?(:record) ? e.record&.class : "n/a"} " \
      "errors=#{e.respond_to?(:record) ? e.record&.errors&.full_messages : "n/a"})",
    )
    raise SocialAuth::ProviderError.new("errors.social_auth.provider_error")
  end

  private

  attr_reader :auth_hash, :birthdate

  def validate_auth_hash!
    raise SocialAuth::ProviderError.new("errors.social_auth.missing_auth_hash") unless auth_hash
    raise SocialAuth::ProviderError.new("errors.social_auth.missing_uid") if uid.blank?
  end

  def provider
    @provider ||= (auth_hash["provider"] || auth_hash[:provider]).to_s
  end

  def uid
    @uid ||= SocialAuthUidExtractor.call(auth_hash: auth_hash)
  end

  def identity_class
    @identity_class ||= SocialIdentifiable.model_for_provider(provider)
  end

  def build_user
    Client.new(
      birthdate: birthdate,
      status_id: ClientStatus::VERIFIED_WITH_SIGN_UP,
      visibility_id: default_visibility_id,
      mfa_level_id: default_mfa_level_id,
      mfa_status_id: default_mfa_status_id,
    )
  end

  def default_visibility_id
    ClientVisibility::STAFF
  end

  def default_mfa_level_id
    ClientMfaLevel::NOTHING
  end

  def default_mfa_status_id
    ClientMfaStatus::UNCONFIGURED
  end

  def ensure_signup_reference_defaults!
    [
      ClientStatus,
      ClientVisibility,
      ClientMfaLevel,
      ClientMfaStatus,
    ].each { |klass| klass.ensure_defaults! if klass.respond_to?(:ensure_defaults!) }
  end

  def ensure_identity_status!
    status_class = identity_class.status_class if identity_class.respond_to?(:status_class)
    return unless status_class

    ensure_reference_record!(status_class, status_class::ACTIVE, "ACTIVE")
  end

  def ensure_reference_record!(model, id, code)
    attributes = { id: id }
    attributes[:code] = code if model.column_names.include?("code")

    model.find_or_create_by!(id: id) do |record|
      attributes.each do |attribute, value|
        record.public_send("#{attribute}=", value)
      end
    end
  end
end
