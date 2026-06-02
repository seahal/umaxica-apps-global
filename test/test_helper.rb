# frozen_string_literal: true

require_relative "../config/environment"
require "rails/test_help"

ENV["RAILS_ENV"] ||= "test"
# Enable YJIT before Rails boots so the boot path and per-test code both
# benefit. The development image doesn't set RUBY_YJIT_ENABLE the way the
# production image does, so the test runner would otherwise execute interpreted.
RubyVM::YJIT.enable if defined?(RubyVM::YJIT)

module ActiveSupport
  class TestCase
    # Keep the default conservative for low-shared-memory local containers.
    # Developers and CI can opt into more workers when the database host has
    # enough shared memory for parallel schema loads.
    parallelize(workers: ENV.fetch("PARALLEL_WORKERS", 1).to_i)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
