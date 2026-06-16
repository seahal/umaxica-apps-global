# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Com::SettingsControllerTest < ActionDispatch::IntegrationTest
  test "show renders" do
    host! ENV.fetch("BASE_CORPORATE_URL", "base.com.localhost")

    get "/settings"

    assert_response :success
    assert_equal "Settings", response.body
  end
end
