# typed: false
# frozen_string_literal: true

require "test_helper"

class Side::App::SettingsControllerTest < ActionDispatch::IntegrationTest
  test "show renders" do
    host! ENV.fetch("SIDE_SERVICE_URL", "side.app.localhost")

    get "/settings"

    assert_response :success
    assert_equal "Settings", response.body
  end
end
