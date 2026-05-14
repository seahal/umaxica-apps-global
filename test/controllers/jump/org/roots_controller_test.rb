# typed: false
# frozen_string_literal: true

require "test_helper"

class Jump::Org::RootsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    host! ENV["JUMP_STAFF_URL"]

    get jump_org_root_url

    assert_response :success
    assert_select "title", "#{ENV.fetch("BRAND_NAME", "UMAXICA").upcase} (org) | Jump"
    assert_select "h1", "Jump::Org::Roots#index"
  end
end
