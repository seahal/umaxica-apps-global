# typed: false
# frozen_string_literal: true

class SocialAuthVerifiedProviderAssertion
  MAX_TOKEN_AGE_SECONDS = 10.minutes.to_i

  def self.call(...)
    new(...).call
  end

  def initialize(auth_hash:, expected_provider:)
    @auth_hash = auth_hash
    @expected_provider = expected_provider.to_s
  end

  def call
    raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless auth_hash
    raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless provider == expected_provider
    raise SocialAuth::ProviderError.new("errors.social_auth.missing_uid") if uid.blank?
    raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless credentials_usable?
    raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless provider_claims_fresh?
    # Reject when the provider explicitly flags the email as unverified. A nil value (claim absent)
    # is allowed because uid+provider is the identity key, not email; some providers omit the claim.
    raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") if email_explicitly_unverified?

    auth_hash
  end

  private

  attr_reader :auth_hash, :expected_provider

  def provider
    auth_value(auth_hash, :provider).to_s
  end

  def uid
    auth_value(auth_hash, :uid).to_s
  end

  def credentials_usable?
    credentials = auth_value(auth_hash, :credentials)
    token = auth_value(credentials, :token)
    expires_at = Integer(auth_value(credentials, :expires_at).to_s, 10)

    token.present? && expires_at > Time.current.to_i
  rescue ArgumentError, TypeError
    false
  end

  def provider_claims_fresh?
    issued_at = claim_value(:iat)
    return true if issued_at.blank?

    issued_at = Integer(issued_at.to_s, 10)
    now = Time.current.to_i
    issued_at <= now && issued_at >= now - MAX_TOKEN_AGE_SECONDS
  rescue ArgumentError, TypeError
    false
  end

  # Returns true only when the provider explicitly sets email_verified=false.
  # A nil/absent claim is treated as "provider does not assert email status" and is allowed
  # because the identity key is uid+provider, not email.
  def email_explicitly_unverified?
    value = claim_value(:email_verified)
    return false if value.nil?

    value == false || value.to_s.casecmp("false").zero?
  end

  def claim_value(key)
    extra = auth_value(auth_hash, :extra)
    id_info = auth_value(extra, :id_info)
    raw_info = auth_value(extra, :raw_info)

    auth_value(id_info, key) || auth_value(raw_info, key)
  end

  def auth_value(source, key)
    return nil unless source
    return source.public_send(key) if source.respond_to?(key)
    return source[key] || source[key.to_s] if source.respond_to?(:[])

    nil
  rescue KeyError
    nil
  end
end
