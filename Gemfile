# frozen_string_literal: true

source "https://rubygems.org"

ruby "4.0.5"

# Type signatures for Ruby libraries.
gem "rbs", require: false
# Rails application framework from the main branch.
gem "rails", github: "rails/rails", branch: "main"
# Rails task runner.
gem "rake"
# Rack webserver interface.
gem "rack"
# Rack request timeout protection.
gem "rack-timeout", group: %i(development production)
# Rack CORS middleware.
gem "rack-cors"
# Puma application server.
gem "puma"
# PostgreSQL database adapter.
gem "pg"
# Counter cache maintenance helpers.
gem "counter_culture"
# SQL query annotations for request tracing.
gem "marginalia"
# Model translation support.
gem "mobility"
# Money and currency handling for Rails models.
gem "money-rails"
# Safe migration guardrails.
gem "strong_migrations"
# PostgreSQL full-text search helpers.
gem "pg_search"
# PostgreSQL database inspection helpers.
gem "rails-pg-extras", require: false
# Browser-based database console.
gem "rails_db"
# Redis client.
gem "redis"
# JSON response builder.
gem "jbuilder"
# OpenStruct standard library dependency.
gem "ostruct"
# Windows and JRuby time zone data.
gem "tzinfo-data", platforms: %i(windows jruby)
# Bootsnap boot cache.
gem "bootsnap", require: false
# Password hashing with Argon2.
gem "argon2"
# Password hashing with BCrypt.
gem "bcrypt"
# SHA-3 digest implementation.
gem "sha3", require: false
# File upload toolkit.
gem "shrine"
# Image processing integration.
gem "image_processing", require: false
# AWS SNS client for SMS delivery.
gem "aws-sdk-sns", require: false
# Propshaft asset pipeline.
gem "propshaft"
# Tailwind CSS integration.
gem "tailwindcss-rails"
# HTML metadata helpers.
gem "meta-tags"
# OpenTelemetry SDK.
gem "opentelemetry-sdk", require: false
# OpenTelemetry OTLP exporter.
gem "opentelemetry-exporter-otlp", require: false
# OpenTelemetry auto-instrumentation bundle.
gem "opentelemetry-instrumentation-all", require: false
# Sentry Ruby client.
gem "sentry-ruby"
# Sentry Rails integration.
gem "sentry-rails"
# Action Policy authorization.
gem "action_policy"
# WebAuthn FIDO2 authentication.
gem "webauthn"
# TOTP generation and verification.
gem "rotp"
# QR code generation.
gem "rqrcode", require: false
# OmniAuth core middleware.
gem "omniauth"
# OmniAuth Apple strategy.
gem "omniauth-apple"
# OmniAuth Google OAuth2 strategy.
gem "omniauth-google-oauth2"
# OmniAuth CSRF protection for Rails.
gem "omniauth-rails_csrf_protection"
# JSON Web Token support.
gem "jwt"
# Web Push notification support.
gem "web-push", require: false
# Native Action Push integration.
gem "action_push_native", require: false
# Solid Cache backend.
gem "solid_cache"
# Solid Queue backend.
gem "solid_queue"
# Turbo Rails integration.
gem "turbo-rails"
# Stimulus Rails integration.
gem "stimulus-rails"
# Inertia Rails adapter.
gem "inertia_rails"
# Vite Rails integration.
gem "vite_rails"
# Pagination helpers.
gem "pagy"
# Nanoid identifier generation.
gem "nanoid"
# Soft deletion support.
gem "discard"
# Store-backed attribute helpers.
gem "store_attribute"
# Store-backed model objects.
gem "store_model"
# Stripe API client.
gem "stripe", require: false
# dependency
gem "ruby-vips"
# log
gem "lograge"
# json
gem "json-canonicalization"
# Solid Queue operations UI.
gem "mission_control-jobs"

group :development, :test do
  # Test coverage reporting.
  gem "simplecov", require: false
  # LCOV formatter for SimpleCov.
  gem "simplecov-lcov", require: false
  # Minitest mock extraction.
  gem "minitest-mock"
  # Slow test profiling.
  gem "test-prof", require: false
  # N+1 query detector alternative.
  gem "prosopite"
  # SQL query parser.
  gem "pg_query", require: false
  # Database consistency checks.
  gem "database_consistency", require: false
  # OpenAPI contract checker.
  gem "committee-rails", require: false
  # Dead code detector.
  gem "debride", require: false
  # RBI generation for Sorbet.
  gem "tapioca", require: false
  # gem "findbug"
  # Static security scanner.
  gem "brakeman", require: false
  # Bundler vulnerability scanner.
  gem "bundler-audit", require: false
  # RuboCop core linter.
  gem "rubocop", require: false
  # RuboCop AST utilities.
  gem "rubocop-ast", require: false
  # RuboCop performance rules.
  gem "rubocop-performance", require: false
  # RuboCop thread-safety rules.
  gem "rubocop-thread_safety", require: false
  # RuboCop Rake rules.
  gem "rubocop-rake", require: false
  # RuboCop Minitest rules.
  gem "rubocop-minitest", require: false
  # RuboCop Rails omakase rules.
  gem "rubocop-rails-omakase", require: false
  # RuboCop i18n rules.
  gem "rubocop-i18n", require: false
  # RuboCop RubyCW rules.
  gem "rubocop-rubycw", require: false
  # RuboCop Rails rules.
  gem "rubocop-rails", require: false
end

group :test do
  # Mutation testing for Minitest.
  gem "mutant-minitest", require: false
  # Browser and integration testing DSL.
  gem "capybara"
  # Playwright Ruby client.
  gem "playwright-ruby-client", require: false
  # Capybara Playwright driver.
  gem "capybara-playwright-driver", require: false
  # Memory allocation profiler.
  gem "memory_profiler", require: false
  # Ruby CPU profiler.
  gem "ruby-prof", require: false
  # Rails memory and boot profiling tools.
  gem "derailed_benchmarks", require: false
  # Sampling profiler.
  gem "stackprof", require: false
  # Minitest output formatters.
  gem "minitest-reporters", require: false
end

group :development do
  # Debugging tools.
  gem "debug", platforms: %i(mri windows)
  # Procfile process manager.
  gem "foreman", require: false
  # Documentation generator.
  gem "yard", require: false
  # Browser email previewer.
  gem "letter_opener", require: false
  # Web UI for email previews.
  gem "letter_opener_web", require: false
  # Hotwire live reload helper.
  gem "hotwire-spark"
  # Rails live reload helper.
  gem "rails_live_reload"
  # Rack live reload middleware.
  gem "rack-livereload"
  # Request performance profiler.
  gem "rack-mini-profiler"
  # PostgreSQL dashboard.
  gem "pghero", require: false
  # SQL exploration dashboard.
  gem "blazer", require: false
  # Package boundary enforcement.
  gem "packwerk", require: false
  # ERB linter.
  gem "erb_lint", require: false
  # Model and route annotation tool.
  gem "annotaterb", require: false
  # Ruby language server.
  gem "ruby-lsp", require: false
  # ABC complexity analyzer.
  gem "flog", require: false
  # Duplicate code detector.
  gem "flay", require: false
  # Code smell detector.
  gem "reek", require: false
end
