# typed: false
# frozen_string_literal: true

# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Use the cheapest password hashing cost in tests. Honored by both bcrypt and
  # argon2 (ActiveModel::SecurePassword::Argon2Password switches to the
  # :unsafe_cheapest profile when min_cost is true). Set after initialization so
  # the secure_password algorithm is loaded first.
  config.after_initialize { ActiveModel::SecurePassword.min_cost = true }

  # While tests run files are not watched, reloading is not necessary.
  config.enable_reloading = false

  # Eager loading loads your entire application before parallel workers fork.
  # Process-based parallelize relies on this so each worker inherits the loaded
  # constant table via copy-on-write instead of repeating cold autoload after fork.
  config.eager_load = true

  # Configure public file server for tests with cache-control for performance.
  config.public_file_server.headers = { "cache-control" => "public, max-age=3600" }

  # Show full error reports.
  config.consider_all_requests_local = true

  # Cache store for test environment
  config.cache_store = :null_store
  config.x.rate_limit.store = ActiveSupport::Cache::MemoryStore.new
  config.solid_cache.connects_to = { shards: { cache: { writing: :cache, reading: :cache_replica } } }

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

  # Raise error for missing translations in controllers, views, and models.
  config.i18n.raise_on_missing_translations = :strict

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Disallow deprecated .connection usage (must use .with_connection for multi-DB)
  config.active_record.permanent_connection_checkout = :deprecated
  config.active_record.async_query_executor = nil

  # Raise on SQL warnings from PostgreSQL.
  config.active_record.db_warnings_action = :raise
  config.active_record.dump_schema_after_migration = false

  # Detect N+1 queries and raise errors immediately.
  config.active_record.strict_loading_by_default = true
  config.active_record.strict_loading_mode = :n_plus_one_only
  config.active_record.action_on_strict_loading_violation = :raise

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true

  # Disable Rails logging during tests for better suite performance.
  config.logger = Logger.new(nil)
  config.log_level = :fatal

  # ci seed up.
  if ENV["CI"]
    config.assets.compile = false
    config.assets.gzip = false
  end

  # SMS Provider Configuration - Use test provider in test environment
  config.sms_provider = "test"
  config.x.security.allow_turnstile_validation_override = true

  # Keep test tables logged. Unlogged tables require PostgreSQL shared memory
  # that is too small in the local multi-DB test container.
  ActiveSupport.on_load(:active_record_postgresqladapter) do
    self.create_unlogged_tables = false
  end

  config.after_initialize do
    require Rails.root.join("test/support/missing_helpers")
    ActiveSupport.on_load(:active_support_test_case) do
      include MissingHelpers
    end
    Minitest::Test.include(MissingHelpers) if defined?(Minitest::Test)
  end

  # Log slow queries over 100ms.
  config.active_record.query_log_tags_enabled = true
end
