# typed: false
# frozen_string_literal: true

module Dpop
  class NonceService
    REDIS_KEY_PREFIX = "dpop:nonce"
    TTL_SECONDS = 300

    def self.generate
      nonce = SecureRandom.urlsafe_base64(32)
      store(nonce)
      nonce
    end

    def self.verify(nonce)
      return false if nonce.blank?
      return false unless redis_available?

      key = "#{REDIS_KEY_PREFIX}:#{nonce}"
      redis.exists?(key).present?
    end

    def self.store(nonce)
      return unless redis_available?

      key = "#{REDIS_KEY_PREFIX}:#{nonce}"
      redis.set(key, "1", ex: TTL_SECONDS)
    end

    def self.redis
      REDIS_CLIENT
    end

    def self.redis_available?
      redis.ping == "PONG"
    rescue Redis::CannotConnectError, Redis::ConnectionError, StandardError
      false
    end
  end
end
