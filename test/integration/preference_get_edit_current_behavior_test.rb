# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceGetEditCurrentBehaviorTest < ActionDispatch::IntegrationTest
  test "GET edit currently creates missing child preference row" do
    host! "base.app.localhost"

    get "/preference?ri=jp"

    assert_response :success
    preference = AppPreference.order(:created_at).last

    assert_not_nil preference

    AppPreferenceTheme.where(preference_id: preference.id).find_each(&:destroy!)

    assert_difference -> { AppPreferenceTheme.where(preference_id: preference.id).count }, 1 do
      get "/preference/theme/edit?ri=jp"
    end

    assert_response :success
  end
end
