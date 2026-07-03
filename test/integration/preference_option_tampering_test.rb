# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceOptionTamperingTest < ActionDispatch::IntegrationTest
  test "theme update ignores invalid option id without changing canonical preference" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    get base_app_preference_path(ri: "jp")
    assert_response :success

    preference = AppPreference.order(:created_at).last
    original_option_id = preference.app_preference_theme.option_id

    patch base_app_preference_theme_path(ri: "jp"),
          params: { preference_theme: { option_id: 99_999 } }

    assert_response :redirect
    assert_equal original_option_id, preference.reload.app_preference_theme.option_id
  end

  test "timezone update ignores invalid timezone without changing canonical preference" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    get base_app_preference_path(ri: "jp")
    assert_response :success

    preference = AppPreference.order(:created_at).last
    original_option_id = preference.app_preference_timezone.option_id

    patch base_app_preference_timezone_path(ri: "jp"),
          params: { preference_timezone: { option_id: "Mars/Olympus" } }

    assert_response :redirect
    assert_equal original_option_id, preference.reload.app_preference_timezone.option_id
  end
end
