# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "support/missing_helpers"
require "support/auth_helpers"

module ActiveSupport
  class TestCase
    # Rails gives PARALLEL_WORKERS precedence over this call's workers argument.
    # Global fixtures span many databases and deadlock when multiple workers
    # toggle PostgreSQL referential integrity on the same databases, so force
    # rails test to remain single-worker unless fixture loading is redesigned.
    ENV["PARALLEL_WORKERS"] = "1"
    parallelize(workers: 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    setup do
      # Locale is global process state; reset it because many controller/helper
      # tests assert locale-sensitive validation messages.
      I18n.locale = I18n.default_locale # rubocop:disable Rails/I18nLocaleAssignment
    end

    teardown do
      I18n.locale = I18n.default_locale # rubocop:disable Rails/I18nLocaleAssignment
    end

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include AuthHelpers
  include MissingHelpers
end
