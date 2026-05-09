# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Net::HealthControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    host! ENV["SIGN_NETWORK_URL"]
    get sign_net_health_url

    assert_response :success
  end
end
