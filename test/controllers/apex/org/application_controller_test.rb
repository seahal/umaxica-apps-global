# typed: false
# frozen_string_literal: true

require "test_helper"

module Apex
  module Org
    class ApplicationControllerTest < ActionDispatch::IntegrationTest
      test "includes expected concerns" do
        controller = ApplicationController.new

        assert_includes controller.class, RateLimit
        assert_includes controller.class, ::Preference::Global
        assert_includes controller.class, ::Preference::Adoption
        assert_includes controller.class, ::Authentication::Staff
        assert_includes controller.class, ::Authorization::Staff
        assert_includes controller.class, ::Verification::Staff
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

        assert_includes before_filters, :check_default_rate_limit
        assert_includes before_filters, :transparent_refresh_access_token
        assert_includes before_filters, :enforce_access_policy!
        assert_includes before_filters, :enforce_verification_if_required
        assert_includes before_filters, :set_current
      end

      test "has finish_request append_after_action" do
        callbacks = ApplicationController._process_action_callbacks
        after_filters = callbacks.select { |c| c.kind == :after }.map(&:filter)

        assert_includes after_filters, :purge_current
      end

      test "has oidc_client_id method" do
        controller = ApplicationController.new

        assert_respond_to controller, :oidc_client_id
        assert_equal "apex_org", controller.send(:oidc_client_id)
      end

      test "has oidc_sign_host method" do
        controller = ApplicationController.new

        assert_respond_to controller, :oidc_sign_host
      end
    end
  end
end
