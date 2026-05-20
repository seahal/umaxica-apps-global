# typed: false
# frozen_string_literal: true

module Dpop
  class JtiReplayGuard
    REDIS_KEY_PREFIX = "dpop:jti"
    TTL_SECONDS = 300

    def self.record!(jti)
      return false if jti.blank?

      key = "#{REDIS_KEY_PREFIX}:#{jti}"
      return cache_record!(key) unless redis_available?

      result = redis.set(key, "1", nx: true, ex: TTL_SECONDS)
      result == true || result == "OK"
    end

    def self.recorded?(jti)
      return false if jti.blank?

      key = "#{REDIS_KEY_PREFIX}:#{jti}"
      return cache_recorded?(key) unless redis_available?

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

    def self.cache_record!(key)
      Rails.cache.write(key, "1", expires_in: TTL_SECONDS.seconds, unless_exist: true)
    end

    def self.cache_recorded?(key)
      Rails.cache.exist?(key)
    end
  end
end
