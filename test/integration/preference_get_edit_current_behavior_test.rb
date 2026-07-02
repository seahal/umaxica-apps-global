# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceGetEditCurrentBehaviorTest < ActionDispatch::IntegrationTest
  test "GET edit does not create a missing child preference row" do
    host! "base.app.localhost"

    get "/preference?ri=jp"

    assert_response :success
    preference = AppPreference.order(:created_at).last

    assert_not_nil preference

    AppPreferenceTheme.where(preference_id: preference.id).find_each(&:destroy!)

    assert_no_difference -> { AppPreferenceTheme.where(preference_id: preference.id).count } do
      get "/preference/theme/edit?ri=jp"
    end

    assert_response :success
  end

  test "GET edit still renders a default value when the child row is missing" do
    host! "base.app.localhost"

    get "/preference?ri=jp"

    assert_response :success
    preference = AppPreference.order(:created_at).last

    AppPreferenceTheme.where(preference_id: preference.id).find_each(&:destroy!)

    get "/preference/theme/edit?ri=jp"

    assert_response :success
    assert_nil AppPreferenceTheme.find_by(preference_id: preference.id)
  end
end
