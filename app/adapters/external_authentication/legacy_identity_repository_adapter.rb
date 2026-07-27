# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class LegacyIdentityRepositoryAdapter
    include ExternalIdentityRepositoryPort

    attr_reader :provider, :model_class

    def initialize(provider:, model_class:, stored_providers:)
      @provider = provider.to_s.freeze
      @model_class = model_class
      @stored_providers = stored_providers.map { |value| value.to_s.freeze }.freeze
    end

    def find_by_subject(subject, lock:)
      scope = model_class.where(uid: subject.to_s, provider: stored_providers)
      scope = scope.lock if lock
      scope.first
    end

    def find_for_user(user)
      model_class.find_by(user_id: user.id)
    end

    def build_for_user(user:, principal:, credential_candidate:)
      validate_principal!(principal)
      model_class.new(
        uid: principal.subject,
        provider: provider,
        user: user,
        **credential_attributes(credential_candidate),
      )
    end

    def refresh_credentials!(identity, principal:, credential_candidate:)
      validate_identity!(identity)
      validate_principal!(principal)
      identity.assign_attributes(credential_attributes(credential_candidate))
      identity.last_authenticated_at = Time.current
      identity.save!
      identity
    end

    def assign_to_user(identity, user)
      validate_identity!(identity)
      identity.user = user
      identity
    end

    def activate!(identity)
      validate_identity!(identity)
      identity.update!(model_class.status_column => model_class.status_class::ACTIVE)
      identity
    end

    def destroy!(identity)
      validate_identity!(identity)
      identity.destroy!
    end

    def refresh_token_for(identity)
      validate_identity!(identity)
      return nil unless provider == "apple"

      identity.refresh_token.presence
    end

    def ensure_active_status!
      status_class = model_class.status_class
      attributes = { id: status_class::ACTIVE }
      attributes[:code] = "ACTIVE" if status_class.column_names.include?("code")
      status_class.find_or_create_by!(id: status_class::ACTIVE) do |record|
        attributes.each do |attribute, value|
          record.public_send("#{attribute}=", value)
        end
      end
    end

    private

    attr_reader :stored_providers

    def credential_attributes(credential_candidate)
      LegacyIdentityCredentialAttributes.new(
        provider: provider,
        credential_candidate: credential_candidate,
      ).to_h
    end

    def validate_principal!(principal)
      return if principal.is_a?(VerifiedPrincipal) && principal.provider == provider

      raise ArgumentError, "principal does not match repository provider"
    end

    def validate_identity!(identity)
      return if identity.is_a?(model_class)

      raise ArgumentError, "identity does not match repository model"
    end
  end
end
