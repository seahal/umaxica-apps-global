# typed: false
# frozen_string_literal: true

require "test_helper"

class ApexTestCsrfController < Apex::App::BareController
  def show
    render plain: form_authenticity_token
  end

  def create
    head :ok
  end
end

class ApexPublicControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

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

  test "no Actor state leaks into response" do
    host! ENV["APEX_SERVICE_URL"]
    original_session = Actor.session

    get "/health"

    assert_response :success

    # Actor.session should remain unchanged
    if original_session.nil?
      assert_nil Actor.session
    else
      assert_equal original_session, Actor.session
    end
  end

  test "POST without CSRF token returns 422" do
    Rails.application.routes.draw do
      get("/test_csrf", to: "apex_test_csrf#show")
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

  test "POST with CSRF token returns successfully" do
    Rails.application.routes.draw do
      get("/test_csrf", to: "apex_test_csrf#show")
      post("/test_csrf", to: "apex_test_csrf#create")
    end
    host!(ENV["APEX_SERVICE_URL"])
    with_forgery_protection do
      post("/test_csrf", headers: csrf_headers(fetch_csrf_token("/test_csrf")))
    end

    assert_response :success
  ensure
    Rails.application.reload_routes!
  end

  test "no preference state leaks on public endpoints" do
    host! ENV["APEX_SERVICE_URL"]
    original_preference = Actor.preference

    get "/health"

    assert_response :success

    assert_equal original_preference, Actor.preference
    assert_equal Actor::Preference::NULL, Actor.preference
  end
end
