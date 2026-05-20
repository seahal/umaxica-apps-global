# typed: false
# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "support/auth_helpers"
require_relative "support/missing_helpers"

# Enable Prosopite logging
# Prosopite.rails_logger = true
# Prosopite.raise = true

if ENV["FPROF"] || ENV["TEST_STACK_PROF"] || ENV["EVENT_PROF"] || ENV["TEST_RUBY_PROF"]
  require "test-prof"
end

# test/test_helper.rb
# require "minitest/reporters"
# Minitest::Reporters.use!(
#  Minitest::Reporters::SpecReporter.new,
# )

module ActiveSupport
  class TestCase
    self.use_transactional_tests = true

    # Run tests in parallel with specified workers.
    #
    # NOTE: Do NOT use :number_of_processors here. This is a multi-database app
    # (~25 test databases) and most test files load `fixtures :all` (190
    # fixtures). The bottleneck is the PostgreSQL server and per-worker fixture
    # loading, not CPU. Measured on a 32-core box (test/models, 1866 runs):
    #   4 workers  -> 14.7s real /  32s cpu
    #   16 workers -> 14.6s real / 123s cpu
    #   32 workers -> 19.4s real / 215s cpu  (slower AND 7x cpu)
    # Wall-clock is flat from 4..16 workers, so default to 4 and allow override.
    parallelize(workers: Integer(ENV.fetch("PARALLEL_WORKERS", 4)))

    REFERENCE_FIXTURES = %i(
      client_statuses client_visibilities client_multi_factors client_multi_factor_statuses
      client_token_kinds client_token_statuses client_token_binding_methods client_token_dbsc_statuses
      client_social_google_statuses client_social_apple_statuses
      operator_identity_statuses operator_visibilities operator_multi_factors operator_multi_factor_statuses
      operator_token_kinds operator_token_statuses operator_token_binding_methods operator_token_dbsc_statuses
    ).freeze

    FIXTURE_DEPENDENCIES = {
      clients: %i(client_statuses client_visibilities client_multi_factors client_multi_factor_statuses),
      operators: %i(operator_identity_statuses operator_visibilities operator_multi_factors
                    operator_multi_factor_statuses),
    }.freeze

    class << self
      def fixtures_only(*fixture_set_names)
        self.fixture_table_names = []
        fixtures(*expand_fixture_dependencies(fixture_set_names))
      end

      def fixtures_none!
        self.fixture_table_names = []
      end

      private

      def expand_fixture_dependencies(fixture_set_names)
        return fixture_set_names if fixture_set_names.include?(:all) || fixture_set_names.include?("all")

        expanded_names = REFERENCE_FIXTURES + fixture_set_names.flat_map do |fixture_set_name|
          fixture_key = fixture_set_name.to_sym

          [fixture_set_name, *FIXTURE_DEPENDENCIES.fetch(fixture_key, [])]
        end

        expanded_names.uniq
      end
    end

    # Setup all fixtures in test/fixtures/*.yml by default. Use fixtures_only in
    # focused tests that need a narrower fixture set for speed.
    fixtures :all

    include AuthHelpers
    include MissingHelpers

    # Avoid N+1 queries
    setup do
      Prosopite.scan if defined?(Prosopite)
    end
    teardown do
      Prosopite.finish if defined?(Prosopite)
    end
  end
end

class ActionDispatch::IntegrationTest
  include AuthHelpers
  prepend MissingHelpers
end
