# typed: false
# frozen_string_literal: true

require "test_helper"

module Apex
  module App
    # Apex::App::BareController intentionally makes `public_strict!` a no-op:
    # every controller below it must be a public, self-defending endpoint
    # (health, robots, sitemaps, csp-report, open, or an auth flow that
    # enforces its own pipeline). If a new controller is added under this
    # base, that is a security-relevant decision and this pin-down test must
    # fail so the addition gets explicit review instead of silently inheriting
    # the relaxed boundary.
    class BareControllerTest < ActiveSupport::TestCase
      fixtures_none!

      ALLOWED_DESCENDANTS = %w(
        Apex::App::Auth::CallbacksController
        Apex::App::CspViolationReportsController
        Apex::App::Edge::V0::CookiesController
        Apex::App::Edge::V0::HealthsController
        Apex::App::HealthsController
        Apex::App::OpenController
        Apex::App::RobotsController
        Apex::App::RootsController
        Apex::App::SitemapsController
        Apex::App::Sso::AuthorizationsController
        Apex::App::Sso::LogoutsController
        Apex::App::Web::V0::CookiesController
        Apex::App::Web::V0::ThemesController
      ).freeze

      test "public_strict! is an intentional no-op on the bare boundary" do
        assert_respond_to Apex::App::BareController, :public_strict!
        assert_nil Apex::App::BareController.public_strict!
      end

      test "only the reviewed allowlist inherits the bare public boundary" do
        Rails.application.eager_load!

        actual = Apex::App::BareController.descendants.filter_map(&:name).grep(/\AApex::App::/).sort

        assert_not_empty actual, "expected BareController descendants to be loaded after eager_load!"

        assert_equal ALLOWED_DESCENDANTS, actual,
                     "Controllers under Apex::App::BareController changed. Each one inherits a no-op " \
                     "public_strict!; confirm the new/removed controller is a public, self-defending " \
                     "endpoint and update ALLOWED_DESCENDANTS deliberately.\n" \
                     "added:   #{(actual - ALLOWED_DESCENDANTS).inspect}\n" \
                     "removed: #{(ALLOWED_DESCENDANTS - actual).inspect}"
      end
    end
  end
end
