# typed: false
# frozen_string_literal: true

require "test_helper"

module Apex
  module App
    # Apex::App::BareController intentionally avoids the full application stack:
    # every controller below it must be a public, self-defending endpoint
    # (health, robots, sitemaps, csp-report, open, or an auth flow that
    # enforces its own pipeline). If a new controller is added under this
    # base, that is a security-relevant decision and this pin-down test must
    # fail so the addition gets explicit review instead of silently inheriting
    # the relaxed boundary.
    class BareControllerTest < ActiveSupport::TestCase
      fixtures_none!

      ALLOWED_DESCENDANTS = %w(
        Apex::App::CspViolationReportsController
        Apex::App::Edge::V0::HealthsController
        Apex::App::HealthsController
        Apex::App::JwksController
        Apex::App::RobotsController
        Apex::App::SitemapsController
      ).freeze

      test "bare boundary does not inherit the full application controller" do
        assert_equal ActionController::Base, Apex::App::BareController.superclass
        assert_not_operator Apex::App::BareController, :<, Apex::App::ApplicationController
      end

      test "only the reviewed allowlist inherits the bare public boundary" do
        Rails.application.eager_load!

        actual = Apex::App::BareController.descendants.filter_map(&:name).grep(/\AApex::App::/).sort

        assert_not_empty actual, "expected BareController descendants to be loaded after eager_load!"

        assert_equal ALLOWED_DESCENDANTS, actual,
                     "Controllers under Apex::App::BareController changed. Each one inherits the bare " \
                     "boundary; confirm the new/removed controller is a public, self-defending " \
                     "endpoint and update ALLOWED_DESCENDANTS deliberately.\n" \
                     "added:   #{(actual - ALLOWED_DESCENDANTS).inspect}\n" \
                     "removed: #{(ALLOWED_DESCENDANTS - actual).inspect}"
      end
    end
  end
end
