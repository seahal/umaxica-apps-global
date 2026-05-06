# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign::App
  class ApplicationControllerCallbacksTest < ActiveSupport::TestCase
    test "registers moved callbacks in expected order" do
      callbacks = ApplicationController._process_action_callbacks
      before_filters = callbacks.select { |callback| callback.kind == :before }.map(&:filter)

      # NOTE: Since using prepend_before_action,
      # Preference-related callbacks execute before AuthN.
      # Note that prepend_before_action executes in reverse definition order.
      # Actual execution order:
      #   set_color_theme -> set_timezone -> set_locale -> set_region ->
      #   resolve_param_context -> set_preferences_cookie
      expected_before_filters = %i(
        set_color_theme
        set_region
        resolve_param_context
        enforce_restricted_session_guard!
        set_preferences_cookie
        enforce_withdrawal_gate!
        transparent_refresh_access_token
        enforce_access_policy!
        enforce_verification_if_required
      )

      expected_before_filters.each_cons(2) do |first, second|
        assert_operator before_filters.index(first), :<, before_filters.index(second)
      end
    end
  end
end
