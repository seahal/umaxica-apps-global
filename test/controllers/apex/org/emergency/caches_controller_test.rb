# typed: false
# frozen_string_literal: true

require "test_helper"

class Apex::Org::Emergency::CachesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("APEX_STAFF_URL", "www.org.localhost")
  end

  test "routes emergency cache endpoints to apex org controllers" do
    get "http://#{ENV.fetch("APEX_STAFF_URL", "www.org.localhost")}/emergency/app/cache"

    assert_response :success

    assert_equal "apex/org/emergency/app/caches", request.path_parameters[:controller]
    assert_equal "show", request.path_parameters[:action]

    get "http://#{ENV.fetch("APEX_STAFF_URL", "www.org.localhost")}/emergency/com/cache"

    assert_response :success

    assert_equal "apex/org/emergency/com/caches", request.path_parameters[:controller]
    assert_equal "show", request.path_parameters[:action]

    get "http://#{ENV.fetch("APEX_STAFF_URL", "www.org.localhost")}/emergency/org/cache"

    assert_response :success

    assert_equal "apex/org/emergency/org/caches", request.path_parameters[:controller]
    assert_equal "show", request.path_parameters[:action]
  end

  test "GET show returns success for all emergency cache controllers" do
    get apex_org_emergency_app_cache_url

    assert_response :success

    get apex_org_emergency_com_cache_url

    assert_response :success

    get apex_org_emergency_org_cache_url

    assert_response :success
  end

  test "PATCH/PUT update returns no_content for all emergency cache controllers" do
    patch apex_org_emergency_app_cache_url

    assert_response :no_content

    put apex_org_emergency_app_cache_url

    assert_response :no_content

    patch apex_org_emergency_com_cache_url

    assert_response :no_content

    put apex_org_emergency_com_cache_url

    assert_response :no_content

    patch apex_org_emergency_org_cache_url

    assert_response :no_content

    put apex_org_emergency_org_cache_url

    assert_response :no_content
  end

  test "DELETE destroy returns no_content for all emergency cache controllers" do
    delete apex_org_emergency_app_cache_url

    assert_response :no_content

    delete apex_org_emergency_com_cache_url

    assert_response :no_content

    delete apex_org_emergency_org_cache_url

    assert_response :no_content
  end
end
