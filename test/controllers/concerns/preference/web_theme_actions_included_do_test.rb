# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceWebThemeActionsIncludedDoTest < ActiveSupport::TestCase
  test "included do includes Preference::WebThemeEndpoint module" do
    klass =
      Class.new(ApplicationController) do
        include Authentication::Base
        include Preference::WebThemeActions
      end

    assert_includes klass.included_modules, Preference::WebThemeEndpoint
  end
end
