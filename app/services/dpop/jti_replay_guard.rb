# typed: false
# frozen_string_literal: true

module Dpop
  class JtiReplayGuard
    REDIS_KEY_PREFIX = "dpop:jti"
    TTL_SECONDS = 300

    def self.record!(jti)
      return false if jti.blank?
      return false unless redis_available?

      key = "#{REDIS_KEY_PREFIX}:#{jti}"
      result = redis.set(key, "1", nx: true, ex: TTL_SECONDS)
      result == true || result == "OK"
    end

    def self.recorded?(jti)
      return false if jti.blank?
      return false unless redis_available?

      key = "#{REDIS_KEY_PREFIX}:#{jti}"
      redis.exists?(key).present?
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
