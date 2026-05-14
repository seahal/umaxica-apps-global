# typed: false
# frozen_string_literal: true

require "test_helper"

module Apex
  module App
    class ApplicationControllerTest < Minitest::Test
      def test_includes_expected_concerns
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

      def test_has_preference_related_prepend_before_action_callbacks
        callbacks = ApplicationController._process_action_callbacks
        before_filters = callbacks.select { |c| c.kind == :before }.map(&:filter)

        assert_includes before_filters, :set_preferences_cookie
        assert_includes before_filters, :resolve_param_context
        assert_includes before_filters, :set_region
        assert_includes before_filters, :set_color_theme
      end

      def test_has_correct_callback_order
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

      def test_has_finish_request_append_after_action
        callbacks = ApplicationController._process_action_callbacks
        after_filters = callbacks.select { |c| c.kind == :after }.map(&:filter)

        assert_includes after_filters, :purge_current
      end

      def test_has_oidc_client_id_method
        controller = ApplicationController.new

        assert_respond_to controller, :oidc_client_id
        assert_equal "apex_app", controller.send(:oidc_client_id)
      end

      def test_has_oidc_sign_host_method
        controller = ApplicationController.new

        assert_respond_to controller, :oidc_sign_host
      end
    end
  end
end
