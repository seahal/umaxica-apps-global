# frozen_string_literal: true

require "flipper"
require "flipper/ui"
require "flipper/adapters/memory"
require "flipper/adapters/redis"
require "redis"

# The test suite must not depend on a running Valkey instance, mirroring the
# NullRedisClient substitution in config/initializers/redis.rb.
Flipper.configure do |config|
  config.adapter do
    if Rails.env.test?
      Flipper::Adapters::Memory.new
    else
      Flipper::Adapters::Redis.new(Redis.new(url: ENV.fetch("VALKEY_FLIPPER_URL")))
    end
  end
end

Rails.application.configure do
  config.flipper.memoize = true
  config.flipper.preload = true
end

# The UI is mounted on the developer surface (config/routes/base.rb).
Flipper::UI.configure do |config|
  # The version check calls flippercloud.io from the browser on every page load. The control-plane
  # surface must not reach third-party origins to render.
  config.version_check_enabled = false
end
