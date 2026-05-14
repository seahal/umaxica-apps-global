# typed: false
# frozen_string_literal: true

require "test_helper"

class Jump::Com::RootsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    host! ENV["JUMP_CORPORATE_URL"]

    get jump_com_root_url

    assert_response :success
    assert_select "title", "#{ENV.fetch("BRAND_NAME", "UMAXICA").upcase} (com) | Jump"
    assert_select "h1", "Jump::Com::Roots#index"
  end
end
