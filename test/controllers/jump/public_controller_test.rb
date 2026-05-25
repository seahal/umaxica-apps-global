# typed: false
# frozen_string_literal: true

require "test_helper"

class JumpTestCsrfController < Jump::App::BareController
  def show
    render plain: form_authenticity_token
  end

  def create
    head :ok
  end
end

class JumpPublicControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "health endpoint returns successfully" do
    host! ENV.fetch("JUMP_SERVICE_URL", "jump.app.localhost")
    get "/health"

    assert_response :success
  end

  test "rate limit returns 429 when exceeded" do
    host! ENV.fetch("JUMP_SERVICE_URL", "jump.app.localhost")

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
    original_authentication = Actor.authn

    host! ENV.fetch("JUMP_SERVICE_URL", "jump.app.localhost")
    get "/health"

    assert_response :success

    assert_equal original_authentication, Actor.authn
  end

  test "Actor facade is not populated on public endpoints" do
    host! ENV.fetch("JUMP_SERVICE_URL", "jump.app.localhost")

    get "/health"

    assert_response :success

    assert_nil Actor.tld
  end

  test "POST without CSRF token returns 422" do
    Rails.application.routes.draw do
      get("/test_csrf", to: "jump_test_csrf#show")
      post("/test_csrf", to: "jump_test_csrf#create")
    end
    host!(ENV.fetch("JUMP_SERVICE_URL", "jump.app.localhost"))
    with_forgery_protection do
      post("/test_csrf")
    end

    assert_response :unprocessable_content
  ensure
    Rails.application.reload_routes!
  end

  test "POST with CSRF token returns successfully" do
    Rails.application.routes.draw do
      get("/test_csrf", to: "jump_test_csrf#show")
      post("/test_csrf", to: "jump_test_csrf#create")
    end
    host!(ENV["JUMP_SERVICE_URL"])
    with_forgery_protection do
      post("/test_csrf", headers: csrf_headers(fetch_csrf_token("/test_csrf")))
    end

    assert_response :success
  ensure
    Rails.application.reload_routes!
  end

  test "no preference state leaks on public endpoints" do
    host! ENV.fetch("JUMP_SERVICE_URL", "jump.app.localhost")
    original_preference = Actor.preferences

    get "/health"

    assert_response :success

    assert_equal original_preference, Actor.preferences
    assert_equal Actor::Preference::NULL, Actor.preferences
  end
end
