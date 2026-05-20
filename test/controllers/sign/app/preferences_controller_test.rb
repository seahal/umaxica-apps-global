# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"

class Sign::App::PreferencesControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
  end

  test "should get show" do
    assert_no_difference("AppPreference.count") do
      get sign_app_preference_url(ri: "jp")
    end

    assert_response :success
    assert_select "a[href*='/preference/email']", count: 0
  end

  test "show uses english preference description when lx is en for jp region" do
    get sign_app_preference_url(ri: "jp", lx: "en")

    assert_response :success
    assert_includes response.body, "Manage language, theme, and other preferences in one place."
    assert_not_includes response.body, "言語やテーマなどの設定をまとめて変更できます。"
  end

  test "logged in user can get show" do
    get sign_app_preference_url(ri: "jp"),
        headers: as_user_headers(clients(:one), host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"))

    assert_response :success
    assert_select "a[href*='/preference/email']", count: 0
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString
