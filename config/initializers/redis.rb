# typed: false
# frozen_string_literal: true

# Redis configuration for the application
default_redis_url = Rails.app.creds.option(:REDIS_NORMAL_URL, default: "redis://localhost:6379/0")

# TLS is negotiated automatically when REDIS_NORMAL_URL uses the rediss:// scheme
# (required by managed providers such as Upstash). No explicit ssl_params needed here.
redis_config = { url: default_redis_url }

class NullRedisClient
  def ping
    "PONG"
  end
end

REDIS_CLIENT =
  if Rails.env.test?
    NullRedisClient.new
  else
    Redis.new(redis_config)
  end

fail_fast_redis_by_default = Rails.env.development? || Rails.env.production?

# Connection smoke test (skip in test). Development and production fail fast so
# missing Redis is noticed before request-time behavior diverges.
should_smoke_test =
  ENV.fetch("REDIS_SMOKE_TEST", fail_fast_redis_by_default ? "1" : "0") == "1"
fail_fast =
  ENV.fetch("REDIS_FAIL_FAST", fail_fast_redis_by_default ? "1" : "0") == "1"

if should_smoke_test && !Rails.env.test?
  begin
    REDIS_CLIENT.ping
  rescue StandardError => e
    Rails.logger.error("❌ Redis connection failed: #{e.class}: #{e.message}")
    raise e if fail_fast
  end
end
