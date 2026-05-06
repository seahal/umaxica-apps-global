# typed: false
# frozen_string_literal: true

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  # config.publicGe_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  config.asset_host = ENV["ASSET_URL"] || "https://asset-jp.umaxica.net"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  # config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # HSTS with preload support (submit to hstspreload.org after deploying).
  config.ssl_options = {
    hsts: { subdomains: true, preload: true, expires: Integer(2.years, 10) },
  }

  # Log to STDOUT as JSON for Cloud Run visibility.
  STDOUT.sync = true
  STDERR.sync = true
  primary_logger = ActiveSupport::Logger.new($stdout)
  primary_logger.formatter = config.log_formatter if config.log_formatter

  # Use BroadcastLogger (Rails 8 standard) to allow multiple log sinks if needed.
  config.logger = ActiveSupport::BroadcastLogger.new(
    ActiveSupport::TaggedLogging.new(primary_logger),
  )
  config.log_tags = [:request_id]

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/health"

  # Report deprecations via Sentry (do not silence them)
  config.active_support.report_deprecations = true
  config.active_support.deprecation = :notify

  # Treat PostgreSQL warnings as errors (same strict setting as dev/test)
  config.active_record.db_warnings_action = :raise

  # Warn on excessive record fetches (early detection of N+1 and query design issues)
  config.active_record.warn_on_records_fetched_greater_than = 10_000

  # Cache query log tags for performance
  config.active_record.cache_query_log_tags = true

  # Enumerate columns in SELECT to avoid prepared statement cache errors on column changes
  config.active_record.enumerate_columns_in_select_statements = true

  # Require --no-sandbox flag to run destructive console operations
  config.sandbox_by_default = true

  config.cache_store = :solid_cache_store
  config.solid_cache.connects_to = { shards: { cache: { writing: :cache, reading: :cache_replica } } }

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false
  config.action_mailer.delivery_method = :smtp

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: ENV.fetch("ID_SERVICE_URL", "id.app.example.com") }

  # Specify outgoing SMTP server. Remember to add credentials via bin/rails credentials:edit.
  config.action_mailer.smtp_settings = {
    address: "email-smtp.#{ENV.fetch("AWS_SES_REGION", "ap-northeast-1")}.amazonaws.com",
    user_name: Rails.app.creds.require(:AWS_SES_SMTP_USER_NAME),
    password: Rails.app.creds.require(:AWS_SES_SMTP_PASSWORD),
    port: 465,
    tls: true,
    authentication: :login,
  }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [:id]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # Collect all host ENV vars used in route constraints.
  config.hosts = ENV.values_at(
    "ID_SERVICE_URL",
    "ID_CORPORATE_URL",
    "ID_STAFF_URL",
    "JUMP_SERVICE_URL", "JUMP_STAFF_URL", "JUMP_CORPORATE_URL",
    "MAIN_SERVICE_URL", "MAIN_STAFF_URL", "MAIN_CORPORATE_URL",
    "APEX_SERVICE_URL", "APEX_STAFF_URL", "APEX_CORPORATE_URL",
    "CORE_SERVICE_URL", "CORE_STAFF_URL", "CORE_CORPORATE_URL",
    "DOCS_SERVICE_URL", "DOCS_STAFF_URL", "DOCS_CORPORATE_URL",
    "NEWS_SERVICE_URL", "NEWS_STAFF_URL", "NEWS_CORPORATE_URL",
    "HELP_SERVICE_URL", "HELP_STAFF_URL", "HELP_CORPORATE_URL",
  ).compact_blank

  # Skip DNS rebinding protection for health checks and load balancer probes.
  config.host_authorization = { exclude: ->(request) { request.path.start_with?("/health", "/sign/up") } }

  ### Added by owner
  # We've configured this production environment to prevent the delivery of public static content.
  config.public_file_server.enabled = false

  # Enable Gzip compression
  config.middleware.use(Rack::Deflater)

  # Additional security headers
  config.action_dispatch.default_headers.merge!(
    "Referrer-Policy" => "strict-origin-when-cross-origin",
    "X-Permitted-Cross-Domain-Policies" => "none",
  )

  # Explicit SameSite cookie protection (matches Rails 8.1 default, pinned against future changes)
  config.action_dispatch.cookies_same_site_protection = :lax

  # Raise on missing callback actions (same as dev/test)
  config.action_controller.raise_on_missing_callback_actions = true

  # Raise on email delivery errors (immediate detection of SES failures)
  config.action_mailer.raise_delivery_errors = true

  # Raise on missing translation keys (quality assurance for i18n)
  config.i18n.raise_on_missing_translations = true
end
