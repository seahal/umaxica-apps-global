# typed: false
# frozen_string_literal: true

module SocialAuth
  # Extracts the provider uid after the controller-level provider assertion
  # boundary has accepted the OmniAuth payload. Do not fall back to raw ID
  # token claims here; provider gem claim verification differs by strategy.
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
      ]
    end
  end
end
