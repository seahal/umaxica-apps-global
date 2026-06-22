# frozen_string_literal: true

require "active_support/core_ext/object/blank"

if ENV["RAILS_ENV"].present? && ENV["RAILS_ENV"] != "test"
  abort(
    "Refusing to run tests outside RAILS_ENV=test " \
    "(got #{ENV["RAILS_ENV"].inspect}).",
  )
end

ENV["RAILS_ENV"] = "test"

# Enable YJIT before Rails boots.
RubyVM::YJIT.enable if defined?(RubyVM::YJIT)

if ENV["COVERAGE"] == "true"
  require "simplecov"

  SimpleCov.start("rails") do
    enable_coverage :branch

    # Ensure all Ruby files under app/ are included,
    # even if they are not loaded during the test run.
    track_files "app/**/*.rb"

    add_filter "/test/"
    add_filter "/config/"
    add_filter "/vendor/"

    add_group "Controllers", "app/controllers"
    add_group "Models", "app/models"
    add_group "Helpers", "app/helpers"
    add_group "Jobs", "app/jobs"
    add_group "Mailers", "app/mailers"
    add_group "Services", "app/services"
    add_group "Values", "app/values"
    add_group "Forms", "app/forms"
    add_group "Policies", "app/policies"
    add_group "Subscribers", "app/subscribers"
    add_group "Validators", "app/validators"
    add_group "Errors", "app/errors"

    minimum_coverage line: 98
    minimum_coverage_by_file line: 92
  end
end

require_relative "../config/environment"

unless Rails.env.test?
  abort("Refusing to run tests outside RAILS_ENV=test (got #{Rails.env}).")
end

require "rails/test_help"
require_relative "support/auth_helpers"

# Rails' fixture FK validation deadlocks in this multi-DB test suite. The DB
# constraints still enforce integrity when fixtures are loaded.
ActiveRecord.verify_foreign_keys_for_fixtures = false

module ActiveSupport
  class TestCase
    parallelize(workers: 1)
    fixtures :all
  end
end

module ReferenceDefaultsRestorer
  REFERENCE_DEFAULT_MODELS = [
    AppPreferenceBindingMethod,
    AppPreferenceDbscStatus,
    AppPreferenceStatus,
    ComPreferenceBindingMethod,
    ComPreferenceDbscStatus,
    ComPreferenceStatus,
    ClientMfaLevel,
    ClientMfaStatus,
    ClientStatus,
    ClientVisibility,
    ClientTokenBindingMethod,
    ClientTokenDbscStatus,
    ClientTokenKind,
    ClientTokenStatus,
    OperatorMfaLevel,
    OperatorMfaStatus,
    VisitorMfaLevel,
    VisitorMfaStatus,
    OrgPreferenceBindingMethod,
    OrgPreferenceDbscStatus,
    OrgPreferenceStatus,
  ].freeze

  def self.restore_reference_defaults!
    REFERENCE_DEFAULT_MODELS.each do |model|
      model.ensure_defaults! if model.respond_to?(:ensure_defaults!)
    end
  end

  delegate :restore_reference_defaults!, to: :ReferenceDefaultsRestorer

  def after_teardown
    super
  ensure
    restore_reference_defaults!
  end
end

ActiveSupport.on_load(:active_support_test_case) { prepend ReferenceDefaultsRestorer }
ReferenceDefaultsRestorer.restore_reference_defaults!
