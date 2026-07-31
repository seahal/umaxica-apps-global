# typed: false
# frozen_string_literal: true

# Builds ClientExternalIdentity records for tests exercising :common storage
# (app/adapters/external_authentication/identity_repository_factory.rb).
# Mirrors the shape ExternalAuthentication::ProviderRegistry declares for
# apple/google so records match what the real adapters produce.
module ExternalIdentityTestHelper
  LegacyStatus = Data.define(:id)
  ISSUERS = {
    "apple" => "https://appleid.apple.com",
    "google" => "https://accounts.google.com",
  }.freeze

  AUDIENCES = {
    "apple" => "apple-test-client-id",
    "google" => "google-test-client-id",
  }.freeze

  def create_active_external_identity(client:, provider:, subject: "#{provider}-subject-#{SecureRandom.hex(8)}", state: "active")
    ClientExternalIdentity.create!(
      client: client,
      provider: provider,
      issuer: ISSUERS.fetch(provider),
      subject: subject,
      audience: AUDIENCES.fetch(provider),
      verification_authority: "test",
      verified_at: Time.current,
      state: state,
    )
  end

  def client_google_identity_statuses(name)
    LegacyStatus.new((name == :active) ? "active" : "consent_revoked")
  end

  def client_apple_identity_statuses(name)
    state = (name == :active) ? "active" : ((name == :deleted) ? "account_deleted" : "consent_revoked")
    LegacyStatus.new(state)
  end
end

# These facades keep older behavior tests aimed at the canonical table while
# the tests are renamed incrementally. They are never loaded by the application.
class LegacyExternalIdentityTestFacade
  class << self
    attr_accessor :provider

    def relation
      ClientExternalIdentity.where(provider: provider)
    end

    delegate :count, :exists?, to: :relation

    def find_by(attributes)
      relation.find_by(normalize_query(attributes))
    end

    def find_by!(attributes)
      relation.find_by!(normalize_query(attributes))
    end

    def where(attributes)
      relation.where(normalize_query(attributes))
    end

    delegate :filter_attributes, to: :ClientExternalIdentity

    def create!(attributes)
      status = attributes.delete(:user_google_identity_status) || attributes.delete(:user_apple_identity_status)
      subject = attributes.delete(:uid)
      client = attributes.delete(:user)
      attributes.except!(:token, :refresh_token, :expires_at, :token_expires_at)
      ClientExternalIdentity.create!(
        **attributes,
        client: client,
        provider: provider,
        issuer: ExternalIdentityTestHelper::ISSUERS.fetch(provider),
        subject: subject,
        audience: ExternalIdentityTestHelper::AUDIENCES.fetch(provider),
        verification_authority: "test",
        verified_at: Time.current,
        state: status&.id || "active",
      )
    end

    private

    def normalize_query(attributes)
      return attributes unless attributes.is_a?(Hash)

      attributes.transform_keys { |key| { uid: :subject, user: :client }.fetch(key, key) }
    end
  end
end

class ClientGoogleIdentity < LegacyExternalIdentityTestFacade
  self.provider = "google"
end

class ClientAppleIdentity < LegacyExternalIdentityTestFacade
  self.provider = "apple"
end

module ClientGoogleIdentityStatus
  ACTIVE = "active"
  REVOKED = "consent_revoked"
end

module ClientAppleIdentityStatus
  ACTIVE = "active"
  REVOKED = "consent_revoked"
  DELETED = "account_deleted"
end

class ClientExternalIdentity
  alias_attribute :status_id, :state
end
