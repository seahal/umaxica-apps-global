# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceSignScreenActionsTest < ActiveSupport::TestCase
  class ExplicitActionHarness < ApplicationController
    include Preference::SignScreenActions

    before_action :ensure_preferences_record

    def edit
      edit_theme_preference_screen
    end

    def update
      update_theme_preference_screen
    end
  end

  test "including sign screen actions does not expose a controller DSL" do
    assert_not_respond_to ExplicitActionHarness, :preference_screen
  end

  test "controller exposes explicit public actions" do
    assert_includes ExplicitActionHarness.public_instance_methods, :edit
    assert_includes ExplicitActionHarness.public_instance_methods, :update
  end
end
