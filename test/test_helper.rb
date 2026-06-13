# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

# Enable YJIT before Rails boots.
RubyVM::YJIT.enable if defined?(RubyVM::YJIT)

if ENV["COVERAGE"] == "true"
  require "simplecov"

  SimpleCov.start("rails") do
    enable_coverage :branch

    add_filter "/test/"
    add_filter "/config/"
    add_filter "/vendor/"

    add_group "Controllers", "app/controllers"
    add_group "Models", "app/models"
    add_group "Services", "app/services"
    add_group "Values", "app/values"
    add_group "Jobs", "app/jobs"
    add_group "Mailers", "app/mailers"

    minimum_coverage line: 95
    minimum_coverage_by_file line: 90
  end
end

require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: (ENV["COVERAGE"] == "true") ? 1 : :number_of_processors)

    fixtures :all
  end
end
