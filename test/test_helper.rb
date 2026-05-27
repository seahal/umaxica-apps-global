# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

# Preference JWTs are audience-scoped per surface; tests exercise all three
# (.app/.com/.org) so the test process must carry every TLD audience even when
# the developer's .env only configures a subset.
required_pref_audiences = %w(umaxica.app umaxica.com umaxica.org localhost)
existing_pref_audiences = ENV["PREFERENCE_JWT_AUDIENCES"].to_s.split(",").map(&:strip).reject(&:empty?)
merged_pref_audiences = (existing_pref_audiences + required_pref_audiences).uniq
ENV["PREFERENCE_JWT_AUDIENCES"] = merged_pref_audiences.join(",")

COVERAGE_ENABLED = %w(1 true).include?(ENV.fetch("COVERAGE", "").downcase)

if COVERAGE_ENABLED
  require "simplecov"

  SimpleCov.start("rails")
end

require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: COVERAGE_ENABLED ? 1 : :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def load_jump_rt_env!
      Rails.root.join("docker/core/env").read.lines.each do |line|
        key, value = line.strip.split("=", 2)
        next if key.blank? || value.blank?
        next unless key == "JUMP_GATEWAY_URL" || key.match?(/\AJWT_(?:SIGN|ACME|CORE)_(?:APP|COM|ORG)_ACTIVE_KID\z/)

        ENV[key] ||= value.delete_prefix('"').delete_suffix('"')
      end
    end

    def jump_rt_url_from_location(location)
      uri = URI.parse(location)

      assert_equal "jump.umaxica.net", uri.host
      token = Rack::Utils.parse_nested_query(uri.query).fetch("rt")
      JWT.decode(token, nil, false).first.fetch("url")
    end
  end
end
