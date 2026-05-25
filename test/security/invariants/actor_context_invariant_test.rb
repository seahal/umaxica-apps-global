# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class ActorContextInvariantTest < ActiveSupport::TestCase
      fixtures_none!

      test "app owned current attributes subclass is only Actor" do
        Rails.application.eager_load!

        app_owned =
          ActiveSupport::CurrentAttributes.descendants.filter_map do |klass|
            location = Object.const_source_location(klass.name)&.first
            next unless location&.start_with?(Rails.root.join("app").to_s)

            klass.name
          end

        assert_equal ["Actor"], app_owned.sort
      end

      test "normal application layers do not write Actor directly" do
        offenders =
          normal_application_paths.flat_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

            content.each_line.with_index(1).filter_map do |line, line_number|
              next unless line.match?(/\bActor\.(?:update\b|[a-zA-Z_]+\s*=)/)

              "#{relative_path}:#{line_number}: #{line.strip}"
            end
          end

        assert_empty offenders, "Actor writes must go through lifecycle installer code:\n#{offenders.join("\n")}"
      end

      test "old Actor authentication and preference APIs are not used" do
        offenders =
          Rails.root.glob("{app,test}/**/*").flat_map do |path|
            next [] unless File.file?(path) && path.extname.in?(%w(.rb .erb))

            relative_path = path.relative_path_from(Rails.root).to_s
            content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

            content.each_line.with_index(1).filter_map do |line, line_number|
              next if relative_path == "test/security/invariants/actor_context_invariant_test.rb"
              next unless line.match?(/\bActor\.(?:authentication|preference)\b/)

              "#{relative_path}:#{line_number}: #{line.strip}"
            end
          end

        assert_empty offenders, "Use Actor.authn and Actor.preferences instead:\n#{offenders.join("\n")}"
      end

      private

      def normal_application_paths
        Rails.root.glob("{app/controllers,app/services,app/policies,app/views}/**/*").select do |path|
          File.file?(path) && path.extname.in?(%w(.rb .erb))
        end
      end
    end
  end
end
