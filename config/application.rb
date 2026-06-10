# typed: false
# frozen_string_literal: true

require_relative "boot"

require "ipaddr"
require "rails/all"

Bundler.require(*Rails.groups)

# Ensure custom middleware is loaded only if present
surface_middleware_path = File.expand_path("../app/middleware/core/surface_middleware.rb", __dir__)
require_relative "../app/middleware/core/surface_middleware" if File.exist?(surface_middleware_path)
require_relative "../lib/jit_security_active_record_encryption_key_provider"

module Jit
  module TrustedProxiesConfig
    module_function

    def parse(value)
      value.to_s.split(",").filter_map do |proxy|
        normalized = proxy.strip
        next if normalized.empty?

        parse_proxy(normalized)
      end
    end

    def parse_proxy(value)
      IPAddr.new(value)
    rescue IPAddr::InvalidAddressError => e
      raise ArgumentError, "Invalid TRUSTED_PROXIES entry: #{value.inspect}", cause: e
    end
  end

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
    config.action_dispatch.trusted_proxies = TrustedProxiesConfig.parse(ENV["TRUSTED_PROXIES"])

    # Active Record Encryption Configuration
    if %w(test production development).include?(Rails.env)
      encryption_keys = JitSecurityActiveRecordEncryptionKeyProvider.fetch
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
    config.active_record.schema_format = :sql

    # SMS Provider Configuration
    config.sms_provider = ENV.fetch("SMS_PROVIDER", "aws_sns")
    config.aws_region = ENV.fetch("AWS_REGION", "ap-northeast-1")

    # i18n locale bundles and default locale are configured in
    # config/initializers/locale.rb (single source of truth, includes fallbacks).

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
      "ACME_CORPORATE_URL" => "www.com.localhost",
      "ACME_SERVICE_URL" => "www.app.localhost",
      "ACME_STAFF_URL" => "www.org.localhost",
      "ACME_NETWORK_URL" => "www.net.localhost",
      "ACME_DEVELOPER_URL" => "www.dev.localhost",
      "CORE_CORPORATE_URL" => "www.jp.umaxica.com",
      "CORE_SERVICE_URL" => "www.jp.umaxica.app",
      "CORE_STAFF_URL" => "www.jp.umaxica.org",
      "ID_CORPORATE_URL" => "id.umaxica.com",
      "ID_SERVICE_URL" => "id.umaxica.app",
      "ID_STAFF_URL" => "id.umaxica.org",
      "SIGN_CORPORATE_URL" => "id.umaxica.com",
      "SIGN_SERVICE_URL" => "id.umaxica.app",
      "SIGN_STAFF_URL" => "id.umaxica.org",
      "JUMP_CORPORATE_URL" => "jump.example.com",
      "JUMP_SERVICE_URL" => "jump.example.app",
      "JUMP_STAFF_URL" => "jump.example.org",
      "MAIN_CORPORATE_URL" => "main.com.localhost",
      "MAIN_SERVICE_URL" => "main.app.localhost",
      "MAIN_STAFF_URL" => "main.org.localhost",
      "NEWS_CORPORATE_URL" => "news.com.localhost",
      "NEWS_SERVICE_URL" => "news.app.localhost",
      "NEWS_STAFF_URL" => "news.org.localhost",
      "HELP_CORPORATE_URL" => "help.com.localhost",
      "HELP_SERVICE_URL" => "help.app.localhost",
      "HELP_STAFF_URL" => "help.org.localhost",
      "DOCS_CORPORATE_URL" => "docs.com.localhost",
      "DOCS_SERVICE_URL" => "docs.app.localhost",
      "DOCS_STAFF_URL" => "docs.org.localhost",
    }.each do |key, value|
      ENV[key] ||= value
    end
  end
end
