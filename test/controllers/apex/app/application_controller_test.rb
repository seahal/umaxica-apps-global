# typed: false
# frozen_string_literal: true

require "test_helper"

module Apex
  module App
    class ApplicationControllerTest < ActionDispatch::IntegrationTest
      test "includes expected concerns" do
        controller = ApplicationController.new

        assert_includes controller.class, RateLimit
        assert_includes controller.class, ::Preference::Global
        assert_includes controller.class, ::Preference::Adoption
        assert_includes controller.class, ::Authentication::User
        assert_includes controller.class, ::Authorization::User
        assert_includes controller.class, ::Verification::User
        assert_includes controller.class, ActionPolicy::Controller
        assert_includes controller.class, ::Oidc::SsoInitiator
        assert_includes controller.class, ::CurrentSupport
        assert_includes controller.class, ::Finisher
      end

      test "has preference-related prepend_before_action callbacks" do
        callbacks = ApplicationController._process_action_callbacks
        before_filters = callbacks.select { |c| c.kind == :before }.map(&:filter)

        assert_includes before_filters, :set_preferences_cookie
        assert_includes before_filters, :resolve_param_context
        assert_includes before_filters, :set_region
        assert_includes before_filters, :set_color_theme
      end

      test "has correct callback order" do
        callbacks = ApplicationController._process_action_callbacks
        before_filters = callbacks.select { |c| c.kind == :before }.map(&:filter)

        expected_order = %i(
          check_default_rate_limit
          enforce_withdrawal_gate!
          transparent_refresh_access_token
          enforce_access_policy!
          enforce_verification_if_required
          set_current
        )

        expected_order.each_cons(2) do |first, second|
          first_idx = before_filters.index(first)
          second_idx = before_filters.index(second)

          next unless first_idx && second_idx

          assert_operator first_idx, :<, second_idx,
                          "#{first} should come before #{second}"
        end
      end

      test "has finish_request append_after_action" do
        callbacks = ApplicationController._process_action_callbacks
        after_filters = callbacks.select { |c| c.kind == :after }.map(&:filter)

        assert_includes after_filters, :purge_current
      end

      test "has oidc_client_id method" do
        controller = ApplicationController.new

        assert_respond_to controller, :oidc_client_id
        assert_equal "apex_app", controller.send(:oidc_client_id)
      end

      test "has oidc_sign_host method" do
        controller = ApplicationController.new

        assert_respond_to controller, :oidc_sign_host
      end
    end
  end
end
