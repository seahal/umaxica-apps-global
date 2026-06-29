# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Side::Com::SettingsControllerTest < ActionDispatch::IntegrationTest
  test "show renders" do
    host! ENV.fetch("PUBLIC_SIDE_CORPORATE_URL")

    get "/settings"

    assert_response :success
    assert_equal "Settings", response.body
  end
end
