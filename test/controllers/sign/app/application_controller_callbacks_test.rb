# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign::App
  class ApplicationControllerCallbacksTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    test "registers moved callbacks in expected order" do
      callbacks = ApplicationController._process_action_callbacks
      before_filters = callbacks.select { |callback| callback.kind == :before }.map(&:filter)

      expected_before_filters = %i(
        check_default_rate_limit
        set_current_context
        reset_flash
        set_preferences_cookie
        resolve_param_context
        set_region
        transparent_refresh_access_token
        set_current_actor
        apply_localization_preferences
        set_color_theme
        enforce_withdrawal_gate!
        enforce_restricted_session_guard!
        enforce_verification_if_required
        enforce_access_policy!
      )

      expected_before_filters.each_cons(2) do |first, second|
        assert_operator before_filters.index(first), :<, before_filters.index(second)
      end
    end
  end
end
