# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Auth::Com
  class ApplicationControllerTest < ActionDispatch::IntegrationTest
    test "includes expected concerns" do
      controller = ApplicationController.new

      assert_includes controller.class, ::AuthenticationVisitor
      assert_includes controller.class, ::AuthorizationVisitor
      assert_includes controller.class, ::VerificationVisitor
      assert_includes controller.class, ActionPolicy::Controller
      assert_includes controller.class, ::ActorSupport
    end

    test "defines full access controller" do
      assert_equal ::Auth::Com::ApplicationController, ::Auth::Com::FullAccessController.superclass
    end

    test "has verification before access_policy" do
      callbacks = ApplicationController._process_action_callbacks
      before_filters = callbacks.select { |c| c.kind == :before }.map { |c| c.filter.to_s }

      assert_operator before_filters.index("enforce_verification_if_required"), :<,
                      before_filters.index("enforce_access_policy!")
    end

    test "reflects localization and theme after actor context is set" do
      callbacks = ApplicationController._process_action_callbacks
      before_filters = callbacks.select { |callback| callback.kind == :before }.map(&:filter)

      expected_before_filters = %i(
        set_current_context
        set_preferences_cookie
        transparent_refresh_access_token
        set_current_actor
        apply_localization_preferences
        set_color_theme
        enforce_verification_if_required
        enforce_access_policy!
      )

      expected_before_filters.each_cons(2) do |first, second|
        assert_operator before_filters.index(first), :<, before_filters.index(second)
      end
    end

    test "clears actor context through around lifecycle" do
      callbacks = ApplicationController._process_action_callbacks
      around_filters = callbacks.select { |callback| callback.kind == :around }.map(&:filter)

      assert_includes around_filters, :with_actor_lifecycle
    end
  end
end
