# typed: false
# frozen_string_literal: true

require "test_helper"

class Apex::Org::Emergency::TokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("APEX_STAFF_URL", "www.org.localhost")
  end

  test "routes emergency app/com token to apex org controllers" do
    get "http://#{ENV.fetch("APEX_STAFF_URL", "www.org.localhost")}/emergency/app/token"

    assert_response :success

    assert_equal "apex/org/emergency/app/tokens", request.path_parameters[:controller]
    assert_equal "show", request.path_parameters[:action]

    get "http://#{ENV.fetch("APEX_STAFF_URL", "www.org.localhost")}/emergency/com/token"

    assert_response :success

    assert_equal "apex/org/emergency/com/tokens", request.path_parameters[:controller]
    assert_equal "show", request.path_parameters[:action]
  end

  test "GET show returns success" do
    get apex_org_emergency_app_token_url

    assert_response :success
    assert_select "h1", "Emergency Org App Token"

    get apex_org_emergency_com_token_url

    assert_response :success
    assert_select "h1", "Emergency Org Com Token"
  end

  test "PATCH/PUT update redirects to show" do
    patch apex_org_emergency_app_token_url

    assert_response :redirect
    assert_redirected_to apex_org_emergency_app_token_url

    put apex_org_emergency_app_token_url

    assert_response :redirect
    assert_redirected_to apex_org_emergency_app_token_url

    patch apex_org_emergency_com_token_url

    assert_response :redirect
    assert_redirected_to apex_org_emergency_com_token_url

    put apex_org_emergency_com_token_url

    assert_response :redirect
    assert_redirected_to apex_org_emergency_com_token_url
  end
end
