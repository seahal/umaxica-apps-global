# typed: false
# frozen_string_literal: true

require "test_helper"

class Jump::Com::RootsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    host! ENV.fetch("JUMP_CORPORATE_URL", "jump.com.localhost")

    get jump_com_root_url

    assert_response :success
    assert_select "title", "#{ENV.fetch("BRAND_NAME", "UMAXICA").upcase} (com) | Jump"
    assert_select "h1", "UMAXICA (com) | Jump"
  end
end
