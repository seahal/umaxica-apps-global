# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/csrf_route_coverage_helper"

module Security
  module Invariants
    class CsrfSecurityInvariantTest < ActiveSupport::TestCase
      include CsrfRouteCoverageHelper

      fixtures_none!

      # This test pins properties that were reviewed as "No issue found".
      # Update SECURITY_INVARIANTS.md before intentionally changing them.

      EXCEPTION_STRATEGY = ActionController::RequestForgeryProtection::ProtectionMethods::Exception
      NULL_SESSION_STRATEGY = ActionController::RequestForgeryProtection::ProtectionMethods::NullSession

      SURFACE_BASE_CONTROLLERS = [
        Sign::App::ApplicationController,
        Sign::Com::ApplicationController,
        Sign::Org::ApplicationController,
        Sign::App::BareController,
        Sign::Com::BareController,
        Sign::Org::BareController,
        Apex::App::ApplicationController,
        Apex::Com::ApplicationController,
        Apex::Dev::ApplicationController,
        Apex::Net::ApplicationController,
        Apex::Org::ApplicationController,
        Apex::App::BareController,
        Apex::Com::BareController,
        Apex::Dev::BareController,
        Apex::Net::BareController,
        Apex::Org::BareController,
        Jump::App::ApplicationController,
        Jump::Com::ApplicationController,
        Jump::Org::ApplicationController,
        Jump::App::BareController,
        Jump::Com::BareController,
        Jump::Org::BareController,
      ].freeze

      test "surface base controllers use header or legacy token with exception strategy" do
        violations =
          SURFACE_BASE_CONTROLLERS.filter_map do |controller|
            next if controller.forgery_protection_verification_strategy == :header_or_legacy_token &&
              controller.forgery_protection_strategy == EXCEPTION_STRATEGY

            "#{controller.name}: using=#{controller.forgery_protection_verification_strategy.inspect}, " \
              "strategy=#{controller.forgery_protection_strategy}"
          end

        assert_empty violations, "CSRF protection strategy drifted:\n#{violations.join("\n")}"
      end

      test "controllers do not skip forgery protection or use null session" do
        offenders =
          Rails.root.glob("app/controllers/**/*.rb").flat_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

            content.each_line.with_index(1).filter_map do |line, line_number|
              next unless line.match?(/\bskip_forgery_protection\b|\bwith:\s*:null_session\b/)

              "#{relative_path}:#{line_number}: #{line.strip}"
            end
          end

        assert_empty offenders, "CSRF bypass/null_session patterns found:\n#{offenders.join("\n")}"
      end

      test "state changing routes are covered and do not use null session" do
        targets = state_changing_application_route_targets

        assert_not_empty targets, "CSRF route invariant must inspect POST/PATCH/PUT/DELETE routes"

        violations =
          targets.filter_map do |target|
            next unless target.fetch(:controller_class).forgery_protection_strategy == NULL_SESSION_STRATEGY

            "#{target.fetch(:verb)} #{target.fetch(:path)} -> " \
              "#{target.fetch(:controller)}##{target.fetch(:action)}"
          end

        assert_empty violations, "State-changing routes must not use null_session:\n#{violations.join("\n")}"
      end

      test "csrf route coverage test remains present in the suite" do
        assert_path_exists Rails.root.join("test/controllers/security/csrf_route_coverage_test.rb")
      end
    end
  end
end
