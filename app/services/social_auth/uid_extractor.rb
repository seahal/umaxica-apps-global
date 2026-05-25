# typed: false
# frozen_string_literal: true

module SocialAuth
  # Extracts a stable provider uid from OmniAuth callback payloads.
  #
  # uid is sourced exclusively from values that the OmniAuth strategy
  # populated after it verified the upstream credential. We deliberately do
  # NOT decode the raw id_token here — strategies (omniauth-google-oauth2,
  # omniauth-apple) already verify the id_token signature against the
  # provider JWKS before populating these fields, so decoding it again
  # without signature verification would let a forged id_token reach this
  # service if any future strategy stopped populating the upstream fields.
  class UidExtractor
    def self.call(...)
      new(...).call
    end

    def initialize(auth_hash:)
      @auth_hash = auth_hash
    end

    def call
      uid = uid_candidates.find(&:present?)
      raise ProviderError.new("errors.social_auth.missing_uid") if uid.blank?

      uid.to_s
    end

    private

    attr_reader :auth_hash

    def uid_candidates
      [
        auth_hash["uid"] || auth_hash[:uid],
        nested_sub("raw_info"),
        nested_sub("id_info"),
      ]
    end

    def nested_sub(key)
      value = auth_hash.dig("extra", key) || auth_hash.dig(:extra, key.to_sym)
      value&.dig("sub") || value&.dig(:sub)
    end
  end
end
