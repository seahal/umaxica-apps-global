# typed: false
# frozen_string_literal: true

# Redis configuration for the application
default_redis_url = Rails.app.creds.option(:REDIS_NORMAL_URL, default: "redis://localhost:6379/0")

# Configure SSL for production Redis (Upstash requires SSL)
redis_config = { url: default_redis_url }

REDIS_CLIENT = Redis.new(redis_config)

# Connection smoke test (skip in test).
# Default: only fail fast in production. Opt-in for dev via env vars.
should_smoke_test =
  ENV.fetch("REDIS_SMOKE_TEST", Rails.env.production? ? "1" : "0") == "1"
fail_fast =
  ENV.fetch("REDIS_FAIL_FAST", Rails.env.production? ? "1" : "0") == "1"

if should_smoke_test && !Rails.env.test?
  begin
    REDIS_CLIENT.ping
  rescue StandardError => e
    Rails.logger.error("❌ Redis connection failed: #{e.class}: #{e.message}")
    raise e if fail_fast
  end
end
