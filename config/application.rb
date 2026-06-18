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
require_relative "../lib/app_config_loader"

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

    # Register app/errors as an eager-load path (not autoload-only). Adding it to
    # autoload_paths alone excluded it from the default app/* eager-load set, so in
    # eager-loading environments (test/production) the error classes were resolved
    # lazily on first reference and skipped by `zeitwerk:check`. eager_load_paths
    # entries are also autoload paths, so this keeps autoloading and restores
    # boot-time constant verification.
    config.eager_load_paths << Rails.root.join("app/errors")

    ### Added by user
    # Trust X-Forwarded-* headers from reverse proxy (Cloudflare Tunnel, Nginx, etc.)
    # This allows Rails to correctly determine the protocol (HTTP/HTTPS) and host
    config.action_dispatch.trusted_proxies = TrustedProxiesConfig.parse(ENV["TRUSTED_PROXIES"])
    config.x.boot_config = AppConfigLoader.load!

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
    config.active_record.db_warnings_action = :raise

    # Allow per-model/per-attribute i18n error message format customization
    config.active_model.i18n_customize_full_message = true
  end
end
