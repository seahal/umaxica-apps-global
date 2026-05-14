# typed: false
# frozen_string_literal: true

{
  "APEX_CORPORATE_URL" => "www.com.localhost",
  "APEX_SERVICE_URL" => "www.app.localhost",
  "APEX_STAFF_URL" => "www.org.localhost",
  "ID_CORPORATE_URL" => "id.com.localhost",
  "ID_SERVICE_URL" => "id.app.localhost",
  "ID_STAFF_URL" => "id.org.localhost",
  "SIGN_CORPORATE_URL" => "id.com.localhost",
  "SIGN_SERVICE_URL" => "id.app.localhost",
  "SIGN_STAFF_URL" => "id.org.localhost",
  "SIGN_NETWORK_URL" => "id.net.localhost",
  "SIGN_DEVELOPER_URL" => "id.dev.localhost",
  "JUMP_CORPORATE_URL" => "jump.com.localhost",
  "JUMP_SERVICE_URL" => "jump.app.localhost",
  "JUMP_STAFF_URL" => "jump.org.localhost",
  "JUMP_COM_URL" => "jump.com.localhost",
  "JUMP_APP_URL" => "jump.app.localhost",
  "JUMP_ORG_URL" => "jump.org.localhost",
  "EMAIL_ADDRESS_HMAC_SALT" => "test-email-address-hmac-salt",
  "PROMOTIONAL_UNSUBSCRIBE_HMAC_SALT" => "test-promotional-unsubscribe-hmac-salt",
  "TELEPHONE_NUMBER_HMAC_SALT" => "test-telephone-number-hmac-salt",
  "PARALLEL_WORKERS" => "1",
}.each do |key, value|
  ENV[key] = value if ENV[key].blank? || ENV[key].include?("umaxica")
end

# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.
  config.active_support.test_parallelization_threshold = 1_000_000

  # While tests run files are not watched, reloading is not necessary.
  config.enable_reloading = false

  # Eager loading loads your entire application. When running a single test locally,
  # this is usually not necessary, and can slow down your test suite. However, it's
  # recommended that you enable it in continuous integration systems to ensure eager
  # loading is working properly before deploying your code.
  config.eager_load = ENV["CI"].present?

  # Configure public file server for tests with cache-control for performance.
  config.public_file_server.headers = { "cache-control" => "public, max-age=3600" }

  # Show full error reports.
  config.consider_all_requests_local = true
  config.cache_store = :memory_store

  # Render exception templates for rescuable exceptions and raise for other exceptions.
  config.action_dispatch.show_exceptions = :rescuable

  # Keep request forgery protection off by default so the existing suite can migrate in batches.
  # Enable it for inventory runs with:
  #   ACTION_CONTROLLER_ALLOW_FORGERY_PROTECTION=true bin/rails test
  config.action_controller.allow_forgery_protection =
    ActiveModel::Type::Boolean.new.cast(ENV.fetch("ACTION_CONTROLLER_ALLOW_FORGERY_PROTECTION", false))

  # Store uploaded files on the local file system in a temporary directory.
  # config.active_storage.service = :test

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Tell Active Job to use the test adapter
  config.active_job.queue_adapter = :test
  config.solid_queue.connects_to = { database: { writing: :queue, reading: :queue_replica } }

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: "example.com" }

  # Raise on deprecation warnings to catch issues early.
  config.active_support.deprecation = :raise

  # Raise error for missing translations.
  config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Disallow deprecated .connection usage (must use .with_connection for multi-DB)
  config.active_record.permanent_connection_checkout = :disallowed
  config.active_record.async_query_executor = nil

  # Raise on SQL warnings from PostgreSQL.
  config.active_record.db_warnings_action = :raise

  # Detect N+1 queries and raise errors immediately.
  config.active_record.strict_loading_by_default = true
  config.active_record.strict_loading_mode = :n_plus_one_only
  config.active_record.action_on_strict_loading_violation = :raise

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true

  # Set log level to :warn to avoid cluttered output during tests
  config.log_level = :warn

  # The following lines were added by me.
  # Bullet, a gem to help you avoid N+1 queries and unused eager loading.
  # Rails.application.configure do
  #   config.after_initialize do
  #     Bullet.enable = true
  #     Bullet.bullet_logger = true
  #     Bullet.raise = true # raise an error if n+1 query occurs
  #   end
  # end

  # ci seed up.
  if ENV["CI"]
    config.assets.compile = false
    config.assets.gzip = false
  end

  # SMS Provider Configuration - Use test provider in test environment
  config.sms_provider = "test"

  # Use PostgreSQL unlogged tables for faster test performance
  ActiveSupport.on_load(:active_record_postgresqladapter) do
    self.create_unlogged_tables = true
  end

  config.after_initialize do
    %w(
      auth_helpers
      auto_headers
      committee_helper
      cookie_helper
      csrf_test_helpers
      database_setup
      external_network_guard
      i18n_locale_reset
      layout_assertions
      preference_jwt_helper
      rate_limit_store_reset
      root_theme_cookie_helper
      skip_db
      social_callback_test_helper
      taxonomy_test_helper
      treeable_shared_tests
      user_helpers
      visitor_helpers
    ).each do |name|
      require Rails.root.join("test/support/#{name}").to_s
    end
  end
end
