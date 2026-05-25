# typed: false
# frozen_string_literal: true

require "test_helper"

class Jump::App::RootsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    host! ENV.fetch("JUMP_SERVICE_URL", "jump.app.localhost")

    get jump_app_root_url

    assert_response :success
    assert_select "title", "#{ENV.fetch("BRAND_NAME", "UMAXICA").upcase} (app) | Jump"
    assert_select "h1", "UMAXICA (app) | Jump"
  end
end
