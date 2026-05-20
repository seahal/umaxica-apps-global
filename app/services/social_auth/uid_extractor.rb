# typed: false
# frozen_string_literal: true

module SocialAuth
  # Extracts a stable provider uid from OmniAuth callback payloads.
  class UidExtractor
    ALLOWED_ID_TOKEN_ALGORITHMS = %w(RS256 ES256).freeze

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
        uid_from_id_token,
      ]
    end

    def nested_sub(key)
      value = auth_hash.dig("extra", key) || auth_hash.dig(:extra, key.to_sym)
      value&.dig("sub") || value&.dig(:sub)
    end

    def uid_from_id_token
      id_token = auth_hash.dig("credentials", "id_token")
      id_token ||= auth_hash.dig(:credentials, :id_token)
      return nil if id_token.blank?

      return nil unless allowed_id_token_algorithm?(id_token)

      payload = JWT.decode(id_token, nil, false, algorithms: ALLOWED_ID_TOKEN_ALGORITHMS).first
      uid = payload["sub"]
      Rails.logger.debug { "[SocialAuth] Extracted uid from id_token: #{uid&.first(8)}***" }
      uid
    rescue JWT::DecodeError, JSON::ParserError, ArgumentError => e
      Rails.logger.warn("[SocialAuth] Failed to decode id_token: #{e.message}")
      nil
    end

    def allowed_id_token_algorithm?(id_token)
      alg = id_token_algorithm(id_token)
      return true if ALLOWED_ID_TOKEN_ALGORITHMS.include?(alg)

      Rails.logger.warn("[SocialAuth] Rejected id_token with disallowed algorithm: #{alg.inspect}")
      false
    end

    def id_token_algorithm(id_token)
      header_segment = id_token.split(".").first
      padding = "=" * ((4 - (header_segment.length % 4)) % 4)
      header_json = Base64.urlsafe_decode64(header_segment + padding)
      JSON.parse(header_json)["alg"]
    end
  end
end
