# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Net::RootsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    host! ENV["SIGN_NETWORK_URL"]
    get sign_net_root_url

    assert_response :success
  end
end
