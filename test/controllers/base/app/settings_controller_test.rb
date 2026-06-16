# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::SettingsControllerTest < ActionDispatch::IntegrationTest
  test "show renders" do
    host! ENV.fetch("BASE_SERVICE_URL", "base.app.localhost")

    get "/settings"

    assert_response :success
    assert_equal "Settings", response.body
  end
end
