# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Dev::RootsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    host! ENV["SIGN_DEVELOPER_URL"]
    get sign_dev_root_url

    assert_response :success
  end
end
