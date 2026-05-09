# typed: false
# frozen_string_literal: true

require "test_helper"

class Apex::App::Emergency::TokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("APEX_SERVICE_URL", "www.app.localhost")
  end

  test "routes emergency app token to apex app controller" do
    get "http://#{ENV.fetch("APEX_SERVICE_URL", "www.app.localhost")}/emergency/app/token"

    assert_response :success

    assert_equal "apex/app/emergency/app/tokens", request.path_parameters[:controller]
    assert_equal "show", request.path_parameters[:action]
  end

  test "GET show returns success" do
    get apex_app_emergency_app_token_url

    assert_response :success
    assert_select "h1", "Emergency App Token"
  end

  test "PATCH/PUT update redirects to show" do
    patch apex_app_emergency_app_token_url

    assert_response :redirect
    assert_redirected_to apex_app_emergency_app_token_url

    put apex_app_emergency_app_token_url

    assert_response :redirect
    assert_redirected_to apex_app_emergency_app_token_url
  end
end
