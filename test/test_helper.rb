# typed: false
# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    setup do
      Prosopite.scan if defined?(Prosopite)
    end

    teardown do
      Prosopite.finish if defined?(Prosopite)
    end

    # Add more helper methods to be used by all tests here...
  end
end
