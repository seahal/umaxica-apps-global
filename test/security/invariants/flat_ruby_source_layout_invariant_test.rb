# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class FlatRubySourceLayoutInvariantTest < ActiveSupport::TestCase
      fixtures_none!

      FLAT_ROOTS = %w(
        app/services
        app/models/concerns
        app/controllers/concerns
      ).freeze

      EXPLICIT_LIB_ALLOWLIST = %w(
        lib/tasks/
        lib/assets/
        lib/templates/
        lib/generators/
      ).freeze

      test "target application ruby roots do not contain nested ruby files" do
        offenders =
          FLAT_ROOTS.flat_map do |root|
            Rails.root.glob("#{root}/**/*.rb").filter_map do |path|
              relative_path = path.relative_path_from(Rails.root).to_s
              relative_path if relative_path.delete_prefix("#{root}/").include?("/")
            end
          end

        assert_empty offenders, "Nested Ruby files are not allowed:\n#{offenders.join("\n")}"
      end

      test "lib does not contain nested application ruby files" do
        allowed_prefixes = EXPLICIT_LIB_ALLOWLIST + configured_lib_ignore_prefixes
        offenders =
          Rails.root.glob("lib/**/*.rb").filter_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            next if relative_path.start_with?(*allowed_prefixes)

            relative_path if relative_path.delete_prefix("lib/").include?("/")
          end

        assert_empty offenders, "Nested application Ruby files under lib are not allowed:\n#{offenders.join("\n")}"
      end

      test "concern files define matching flat constants" do
        offenders =
          Rails.root.glob("app/{models,controllers}/concerns/**/*.rb").filter_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            basename = path.basename(".rb").to_s
            expected_constant = basename.camelize

            if basename.end_with?("_concern")
              "#{relative_path}: redundant _concern suffix"
            elsif expected_constant.end_with?("Concern")
              "#{relative_path}: redundant Concern constant suffix"
            elsif !Object.const_defined?(expected_constant, false)
              "#{relative_path}: missing #{expected_constant}"
            end
          end

        assert_empty offenders, "Concern layout violations found:\n#{offenders.join("\n")}"
      end

      private

      def configured_lib_ignore_prefixes
        application_config = Rails.root.join("config/application.rb").read
        match = application_config.match(/config\.autoload_lib\(ignore:\s*%w\((?<entries>[^)]*)\)\)/)
        return [] unless match

        match[:entries].split.map { |entry| "lib/#{entry}/" }
      end
    end
  end
end
