# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class PreferenceWebThemeActionsIncludedDoTest < ActiveSupport::TestCase
  test "including web theme actions does not include endpoint implicitly" do
    klass =
      Class.new(ApplicationController) do
        include AuthenticationBase
        include PreferenceWebThemeActions
      end

    assert_not_includes klass.included_modules, PreferenceWebThemeEndpoint
  end

  test "including web theme actions does not register callback skips implicitly" do
    klass =
      Class.new(ApplicationController) do
        include AuthenticationBase
        include PreferenceWebThemeActions
      end

    assert_empty klass._process_action_callbacks.select { |callback| callback.filter == :set_preferences_cookie }
  end
end
