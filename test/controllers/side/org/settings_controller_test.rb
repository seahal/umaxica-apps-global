# typed: false
# frozen_string_literal: true

require "test_helper"

class Side::Org::SettingsControllerTest < ActionDispatch::IntegrationTest
  test "show renders" do
    host! ENV.fetch("SIDE_STAFF_URL")

    get "/settings"

    assert_response :success
    assert_equal "Settings", response.body
  end
end
