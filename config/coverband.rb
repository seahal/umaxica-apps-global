# typed: false
# frozen_string_literal: true

Coverband.configure do |config|
  config.logger = Rails.logger

  # Development and test should boot without a local Redis server.
  # Keep coverage data on disk there, and keep Redis for production.
  if Rails.env.production?
    redis_url =
      ENV["COVERBAND_REDIS_URL"].presence ||
      ENV["REDIS_URL"].presence ||
      "redis://localhost:6379/0"

    config.store = Coverband::Adapters::RedisStore.new(Redis.new(url: redis_url))
  else
    config.store = Coverband::Adapters::FileStore.new(Rails.root.join("tmp/coverband"))
  end

  config.track_views = true
  config.track_routes = true
  config.web_enable_clear = true
end
