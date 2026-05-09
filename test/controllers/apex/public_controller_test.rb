# typed: false
# frozen_string_literal: true

require "test_helper"

class ApexTestCsrfController < Apex::PublicController
  def create
    head :ok
  end
end

class ApexPublicControllerTest < ActionDispatch::IntegrationTest
  test "health endpoint returns successfully" do
    host! ENV["APEX_SERVICE_URL"]
    get "/health"

    assert_response :success
  end

  test "robots.txt endpoint returns successfully" do
    host! ENV["APEX_SERVICE_URL"]
    get "/robots.txt"

    assert_response :success
  end

  test "sitemap.xml endpoint returns successfully" do
    host! ENV["APEX_SERVICE_URL"]
    get "/sitemap.xml"

    assert_response :success
  end

  test "rate limit returns 429 when exceeded" do
    host! ENV["APEX_SERVICE_URL"]
    # Default limit is 300/min
    300.times do
      get "/health"

      assert_response :success
    end

    get "/health"

    assert_response :too_many_requests
    assert_predicate response.headers["Retry-After"], :present?
  end

  test "no Current state leaks into response" do
    host! ENV["APEX_SERVICE_URL"]
    original_session = Current.session

    get "/health"

    assert_response :success

    # Current.session should remain unchanged
    if original_session.nil?
      assert_nil Current.session
    else
      assert_equal original_session, Current.session
    end
  end

  test "POST without CSRF token returns 422" do
    Rails.application.routes.draw do
      post("/test_csrf", to: "apex_test_csrf#create")
    end
    host!(ENV["APEX_SERVICE_URL"])
    with_forgery_protection do
      post("/test_csrf")
    end

    assert_response :unprocessable_content
  ensure
    Rails.application.reload_routes!
  end

  test "no preference state leaks on public endpoints" do
    host! ENV["APEX_SERVICE_URL"]
    original_preference = Current.preference

    get "/health"

    assert_response :success

    assert_equal original_preference, Current.preference
    assert_equal Current::Preference::NULL, Current.preference
  end

  private

  def with_forgery_protection
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
