# typed: false
# frozen_string_literal: true

require "set"

class ExternalAuthenticationLegacyIdentityCopy
  Report = Data.define(:apple_count, :google_count, :copied_count)

  class PreflightError < StandardError
    attr_reader :code

    def initialize(code)
      @code = code
      super(code.to_s)
    end
  end

  class VerificationError < StandardError
    attr_reader :code

    def initialize(code)
      @code = code
      super(code.to_s)
    end
  end

  def self.call(...)
    new(...).call
  end

  def self.preflight!(...)
    new(...).preflight!
  end

  def self.verify!(...)
    new(...).verify!
  end

  def initialize(audience_resolver: nil)
    @audience_resolver = audience_resolver || method(:configured_audience_for)
  end

  def call
    apple_records = ClientAppleIdentity.order(:id).to_a
    google_records = ClientGoogleIdentity.order(:id).to_a
    validate_preflight!(apple_records: apple_records, google_records: google_records)

    AppPrincipalRecord.transaction do
      apple_records.each { |record| copy_apple!(record) }
      google_records.each { |record| copy_google!(record) }
    end

    Report.new(
      apple_count: apple_records.length,
      google_count: google_records.length,
      copied_count: apple_records.length + google_records.length,
    )
  end

  def verify!
    apple_records = ClientAppleIdentity.order(:id).to_a
    google_records = ClientGoogleIdentity.order(:id).to_a
    expected_count = apple_records.length + google_records.length
    raise VerificationError.new(:binding_count_mismatch) unless ClientExternalIdentity.count == expected_count

    apple_records.each { |record| verify_apple!(record) }
    google_records.each { |record| verify_google!(record) }

    Report.new(
      apple_count: apple_records.length,
      google_count: google_records.length,
      copied_count: expected_count,
    )
  end

  def preflight!
    apple_records = ClientAppleIdentity.order(:id).to_a
    google_records = ClientGoogleIdentity.order(:id).to_a
    validate_preflight!(apple_records: apple_records, google_records: google_records)

    Report.new(
      apple_count: apple_records.length,
      google_count: google_records.length,
      copied_count: 0,
    )
  end

  private

  attr_reader :audience_resolver

  def validate_preflight!(apple_records:, google_records:)
    if ClientExternalIdentity.exists? || ClientAppleIdentityCredential.exists?
      raise PreflightError.new(:destination_not_empty)
    end

    seen_subjects = Set.new
    seen_client_providers = Set.new
    (apple_records + google_records).each do |record|
      provider = normalized_provider(record)
      raise PreflightError.new(:inactive_legacy_identity) unless record.active?
      raise PreflightError.new(:missing_legacy_client) if record.user_id.blank?
      raise PreflightError.new(:missing_legacy_subject) if record.uid.blank?

      subject_key = [ExternalAuthentication::ProviderRegistry.fetch(provider).issuer, record.uid]
      raise PreflightError.new(:duplicate_provider_subject) unless seen_subjects.add?(subject_key)

      client_provider_key = [record.user_id, provider]
      raise PreflightError.new(:duplicate_client_provider) unless seen_client_providers.add?(client_provider_key)

      configured_audience_for(provider)
    end
  end

  def copy_apple!(record)
    identity = build_identity(record, provider: "apple")
    identity.save!
    return if record.refresh_token.blank?

    ClientAppleIdentityCredential.create!(
      client_external_identity: identity,
      refresh_token: record.refresh_token,
    )
  end

  def copy_google!(record)
    build_identity(record, provider: "google").save!
  end

  def verify_apple!(record)
    identity = verify_binding!(record, provider: "apple")
    credential = identity.client_apple_identity_credential
    if record.refresh_token.present?
      raise VerificationError.new(:missing_apple_credential) unless credential
      raise VerificationError.new(:apple_credential_mismatch) unless credential.refresh_token == record.refresh_token
    elsif credential
      raise VerificationError.new(:unexpected_apple_credential)
    end
  end

  def verify_google!(record)
    identity = verify_binding!(record, provider: "google")
    raise VerificationError.new(:google_credential_present) if identity.client_apple_identity_credential
  end

  def verify_binding!(record, provider:)
    identity =
      ClientExternalIdentity.find_by(
        provider: provider,
        issuer: ExternalAuthentication::ProviderRegistry.fetch(provider).issuer,
        subject: record.uid,
      )
    raise VerificationError.new(:binding_missing) unless identity
    raise VerificationError.new(:binding_client_mismatch) unless identity.client_id == record.user_id
    raise VerificationError.new(:binding_state_mismatch) unless identity.state == "active"

    identity
  end

  def build_identity(record, provider:)
    ClientExternalIdentity.new(
      client: record.user,
      provider: provider,
      issuer: ExternalAuthentication::ProviderRegistry.fetch(provider).issuer,
      subject: record.uid,
      audience: audience_resolver.call(provider),
      verification_authority: "legacy-social-identity-migration",
      verified_at: record.last_authenticated_at || record.created_at,
      last_authenticated_at: record.last_authenticated_at,
    )
  end

  def normalized_provider(record)
    SocialIdentifiable.normalize_provider(record.provider)
  end

  def configured_audience_for(provider)
    entry = ExternalAuthentication::ProviderRegistry.fetch(provider)
    value = Rails.app.creds.option(entry.audience_credential_key)
    return value if value.is_a?(String) && value.present?

    raise PreflightError.new(:missing_provider_audience)
  end
end
