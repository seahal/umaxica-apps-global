# typed: false
# frozen_string_literal: true

return if Rails.env.test?

# Rack::Timeout reads these ENV variables during middleware initialization.
# Set them before the Railtie inserts the middleware.
ENV["RACK_TIMEOUT_SERVICE_TIMEOUT"] ||= "10"

require "rack-timeout" unless defined?(Rack::Timeout)

if defined?(Rack::Timeout)
  # Elevate Rack::Timeout's own log level to WARN to prevent spamming
  # standard info logs with verbose timeout tracking.
  Rack::Timeout::Logger.level = Logger::WARN
end
