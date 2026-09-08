# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SkipForgeryProtectionUsageTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  # CSP violation reports are browser-generated telemetry POSTs that carry no CSRF token and may
  # arrive with `Origin: null`. The exception is scoped to `create` on an endpoint that records
  # bounded untrusted telemetry and touches no actor, session or cookie state.
  # See app/controllers/concerns/csp_violation_report.rb.
  ALLOWED_SKIP_FORGERY_PROTECTION_PATHS = [
    "app/controllers/concerns/csp_violation_report.rb",
  ].freeze

  test "skip_forgery_protection is only used in approved controllers" do
    # Every `.rb` under app/controllers, not just `*_controller.rb`: the call the allowlist exists
    # to track lives in a concern, so a `*_controller.rb` glob passed while seeing nothing, and a
    # future concern mixed into an Inertia controller would have been invisible to it too.
    controller_files = Rails.root.glob("app/controllers/**/*.rb")

    found_paths =
      controller_files.filter_map do |path|
        content = File.read(path)
        next unless content.match?(/\bskip_forgery_protection\b/)

        path.relative_path_from(Rails.root).to_s
      end

    violations = found_paths - ALLOWED_SKIP_FORGERY_PROTECTION_PATHS
    missing_allowed = ALLOWED_SKIP_FORGERY_PROTECTION_PATHS - found_paths

    assert_empty violations,
                 "skip_forgery_protection must not be added to controllers without review. " \
                 "Remove it from: #{violations.join("\n  ")}"

    assert_empty missing_allowed,
                 "Allowed list contains controllers that no longer call skip_forgery_protection. " \
                 "Please update ALLOWED_SKIP_FORGERY_PROTECTION_PATHS: #{missing_allowed.join("\n  ")}"
  end
end
