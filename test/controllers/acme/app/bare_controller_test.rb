# typed: false
# frozen_string_literal: true

require "test_helper"

module Acme
  module App
    # Acme::App::BareController intentionally avoids the full application stack:
    # every controller below it must be a public, self-defending endpoint
    # (health, robots, sitemaps, csp-report, open, or an auth flow that
    # enforces its own pipeline). If a new controller is added under this
    # base, that is a security-relevant decision and this pin-down test must
    # fail so the addition gets explicit review instead of silently inheriting
    # the relaxed boundary.
    class BareControllerTest < ActiveSupport::TestCase
      fixtures_none!

      REQUIRED_DESCENDANTS = %w(
        Acme::App::CspViolationReportsController
        Acme::App::Edge::V0::HealthsController
        Acme::App::HealthsController
        Acme::App::JwksController
        Acme::App::RobotsController
        Acme::App::SitemapsController
      ).freeze
      OPTIONAL_TEST_DESCENDANTS = %w(
        Acme::App::TestCsrfController
      ).freeze

      test "bare boundary does not inherit the full application controller" do
        assert_equal Acme::App::ApplicationController, Acme::App::BareController.superclass
        assert_operator Acme::App::BareController, :<, Acme::App::ApplicationController
      end

      test "only the reviewed allowlist inherits the bare public boundary" do
        Rails.application.eager_load!

        actual = Acme::App::BareController.descendants.filter_map(&:name).grep(/\AAcme::App::/).sort

        assert_not_empty actual, "expected BareController descendants to be loaded after eager_load!"

        allowed = (REQUIRED_DESCENDANTS + OPTIONAL_TEST_DESCENDANTS).sort
        unexpected = actual - allowed
        missing = REQUIRED_DESCENDANTS - actual

        assert_empty unexpected,
                     "Controllers under Acme::App::BareController changed. Each one inherits the bare " \
                     "boundary; confirm the new/removed controller is a public, self-defending " \
                     "endpoint and update ALLOWED_DESCENDANTS deliberately.\n" \
                     "added:   #{unexpected.inspect}\n" \
                     "removed: #{missing.inspect}"
        assert_empty missing
      end
    end
  end
end
