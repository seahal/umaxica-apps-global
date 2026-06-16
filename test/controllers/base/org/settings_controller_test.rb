# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::SettingsControllerTest < ActionDispatch::IntegrationTest
  test "show renders" do
    host! ENV.fetch("BASE_STAFF_URL", "base.org.localhost")

    get "/settings"

    assert_response :success
    assert_equal "Settings", response.body
  end
end
