# typed: false
# frozen_string_literal: true

unless Rails.env.production?
  Prosopite.rails_logger = true # Logs to Rails logger.
  Prosopite.prosopite_logger = true # Logs to log/prosopite.log.
  Prosopite.raise = Rails.env.local? # Fail fast on N+1 in dev and test.

  # Ignore internal Rails tables during multi-DB boot
  Prosopite.ignore_queries = [
    /SELECT.*FROM.*"ar_internal_metadata"/,
    /SELECT.*FROM.*"schema_migrations"/,
  ]
end

if Rails.env.development?
  require "prosopite/middleware/rack"

  Rails.configuration.middleware.use(Prosopite::Middleware::Rack)
end
