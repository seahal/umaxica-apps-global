# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Dev::HealthControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    host! ENV["SIGN_DEVELOPER_URL"]
    get sign_dev_health_url

    assert_response :success
  end
end
