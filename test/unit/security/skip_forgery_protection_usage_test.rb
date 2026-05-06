# typed: false
# frozen_string_literal: true

require "test_helper"

class SkipForgeryProtectionUsageTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  ALLOWED_SKIP_FORGERY_PROTECTION_PATHS = [].freeze

  test "skip_forgery_protection is only used in approved controllers" do
    controller_files = Rails.root.glob("app/controllers/**/*_controller.rb")

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
