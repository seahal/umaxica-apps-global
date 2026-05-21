# typed: false
# frozen_string_literal: true

require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

# Ensure custom middleware is loaded only if present
subdomain_static_files_path = File.expand_path("../lib/subdomain_static_files.rb", __dir__)
require_relative "../lib/subdomain_static_files" if File.exist?(subdomain_static_files_path)
surface_middleware_path = File.expand_path("../app/middleware/core/surface_middleware.rb", __dir__)
require_relative "../app/middleware/core/surface_middleware" if File.exist?(surface_middleware_path)
require_relative "../lib/jit/security/active_record_encryption_key_provider"

module Jit
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults(8.2)

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # CommonHelper ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Add app/errors to autoload paths
    config.autoload_paths << Rails.root.join("app/errors")

    ### Added by user
    # Trust X-Forwarded-* headers from reverse proxy (Cloudflare Tunnel, Nginx, etc.)
    # This allows Rails to correctly determine the protocol (HTTP/HTTPS) and host
    config.action_dispatch.trusted_proxies =
      (ENV["TRUSTED_PROXIES"]&.split(",") || []).filter_map do |proxy|
        IPAddr.new(proxy.strip)
      rescue IPAddr::InvalidAddressError
        nil
      end

    # Active Record Encryption Configuration
    if %w(test production development).include?(Rails.env)
      encryption_keys = Jit::Security::ActiveRecordEncryptionKeyProvider.fetch
      config.active_record.encryption.primary_key = encryption_keys.fetch(:current)
      config.active_record.encryption.previous = encryption_keys[:previous].map { |previous_key| { key: previous_key } }
      config.active_record.encryption.deterministic_key = encryption_keys.fetch(:deterministic)
      config.active_record.encryption.key_derivation_salt = encryption_keys.fetch(:key_derivation_salt)
    end

    # Rails encrypted/signed cookies derive keys from secret_key_base.
    # Pin modern primitives explicitly and do not keep SHA1 compatibility rotations.
    config.action_dispatch.signed_cookie_digest = "SHA256"
    config.action_dispatch.encrypted_cookie_cipher = "aes-256-gcm"
    config.action_dispatch.use_authenticated_cookie_encryption = true

    # USE UTC
    config.time_zone = "UTC"
    config.active_record.default_timezone = :utc

    # ActiveJob
    # Use Solid Queue for job processing
    config.active_job.queue_adapter = :solid_queue
    config.solid_queue.connects_to = { database: { writing: :queue, reading: :queue_replica } }

    # SMS Provider Configuration
    config.sms_provider = ENV.fetch("SMS_PROVIDER", "aws_sns")
    config.aws_region = ENV.fetch("AWS_REGION", "ap-northeast-1")

    # Load translations from nested locale directories.
    config.i18n.load_path += Rails.root.glob("config/locales/**/*.{rb,yml}")
    config.i18n.load_path.push(Rails.root.join("config/locales/en.yml").to_s)
    config.i18n.load_path.push(Rails.root.join("config/locales/ja.yml").to_s)
    config.i18n.default_locale = :ja

    # Set bigserial as default primary key for new tables
    config.generators do |g|
      g.orm(:active_record, primary_key_type: :bigserial)
    end

    # Multi-database async query executor (one thread pool per database)
    config.active_record.async_query_executor = :multi_thread_pool

    # Required belongs_to validation should confirm the associated row, not only
    # the foreign-key value. Tests that create many records should pass loaded
    # reference associations when they intentionally exercise bulk validation.
    config.active_record.belongs_to_required_validates_foreign_key = true

    # Log SQL warnings from PostgreSQL
    config.active_record.db_warnings_action = :log

    # Allow per-model/per-attribute i18n error message format customization
    config.active_model.i18n_customize_full_message = true

    # Ensure default host environment variables are set for route generation and constraints,
    # especially in test environment where they might not be loaded from external env files.
    {
      "APEX_CORPORATE_URL" => "www.com.localhost",
      "APEX_SERVICE_URL" => "www.app.localhost",
      "APEX_STAFF_URL" => "www.org.localhost",
      "APEX_NETWORK_URL" => "www.net.localhost",
      "APEX_DEVELOPER_URL" => "www.dev.localhost",
      "JUMP_CORPORATE_URL" => "jump.example.com",
      "JUMP_SERVICE_URL" => "jump.example.app",
      "JUMP_STAFF_URL" => "jump.example.org",
      "MAIN_CORPORATE_URL" => "main.com.localhost",
      "MAIN_SERVICE_URL" => "main.app.localhost",
      "MAIN_STAFF_URL" => "main.org.localhost",
      "SIDE_CORPORATE_URL" => "news.com.localhost",
      "SIDE_SERVICE_URL" => "news.app.localhost",
      "SIDE_STAFF_URL" => "news.org.localhost",
      "DOCS_CORPORATE_URL" => "docs.com.localhost",
      "DOCS_SERVICE_URL" => "docs.app.localhost",
      "DOCS_STAFF_URL" => "docs.org.localhost",
    }.each do |key, value|
      ENV[key] ||= value
    end
  end
end
