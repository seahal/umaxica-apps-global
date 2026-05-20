# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceWebThemeActionsIncludedDoTest < ActiveSupport::TestCase
  test "including web theme actions does not include endpoint implicitly" do
    klass =
      Class.new(ApplicationController) do
        include Authentication::Base
        include Preference::WebThemeActions
      end

    assert_not_includes klass.included_modules, Preference::WebThemeEndpoint
  end

  test "including web theme actions does not register callback skips implicitly" do
    klass =
      Class.new(ApplicationController) do
        include Authentication::Base
        include Preference::WebThemeActions
      end

    assert_empty klass._process_action_callbacks.select { |callback| callback.filter == :set_preferences_cookie }
  end
end
