# typed: false
# frozen_string_literal: true

require "test_helper"

module Acme
  module App
    class TestCsrfController < BareController
      AUTHENTICATION_MODE = :bare

      def show
        render plain: form_authenticity_token
      end

      def create
        head :ok
      end
    end
  end
end

class AcmePublicControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "health endpoint returns successfully" do
    host! ENV.fetch("ACME_SERVICE_URL").delete_suffix("/")
    get "/health", params: { ri: "jp" }

    assert_response :success
  end

  test "robots.txt endpoint returns successfully" do
    host! ENV.fetch("ACME_SERVICE_URL").delete_suffix("/")
    get "/robots.txt", params: { ri: "jp" }

    assert_response :success
  end

  test "sitemap.xml endpoint returns successfully" do
    host! ENV.fetch("ACME_SERVICE_URL").delete_suffix("/")
    get "/sitemap.xml", params: { ri: "jp" }

    assert_response :success
  end

  test "rate limit returns 429 when exceeded" do
    host! ENV.fetch("ACME_SERVICE_URL").delete_suffix("/")
    # Default limit is 300/min
    300.times do
      get "/health", params: { ri: "jp" }

      assert_response :success
    end

    get "/health", params: { ri: "jp" }

    assert_response :too_many_requests
    assert_predicate response.headers["Retry-After"], :present?
  end

  test "no Actor state leaks into response" do
    host! ENV.fetch("ACME_SERVICE_URL").delete_suffix("/")
    original_authentication = Actor.authn

    get "/health", params: { ri: "jp" }

    assert_response :success

    assert_equal original_authentication, Actor.authn
  end

  test "POST without CSRF token returns 422" do
    Rails.application.routes.draw do
      get("/test_csrf", to: "acme/app/test_csrf#show")
      post("/test_csrf", to: "acme/app/test_csrf#create")
    end
    host!(ENV.fetch("ACME_SERVICE_URL").delete_suffix("/"))
    with_forgery_protection do
      post("/test_csrf", params: { ri: "jp" })
    end

    assert_response :unprocessable_content
  ensure
    Rails.application.reload_routes!
  end

  test "POST with CSRF token returns successfully" do
    Rails.application.routes.draw do
      get("/test_csrf", to: "acme/app/test_csrf#show")
      post("/test_csrf", to: "acme/app/test_csrf#create")
    end
    host!(ENV.fetch("ACME_SERVICE_URL").delete_suffix("/"))
    with_forgery_protection do
      post("/test_csrf", params: { ri: "jp" }, headers: csrf_headers(fetch_csrf_token("/test_csrf?ri=jp")))
    end

    assert_response :success
  ensure
    Rails.application.reload_routes!
  end

  test "no preference state leaks on public endpoints" do
    host! ENV.fetch("ACME_SERVICE_URL").delete_suffix("/")
    original_preference = Actor.preferences

    get "/health", params: { ri: "jp" }

    assert_response :success

    assert_equal original_preference, Actor.preferences
    assert_equal Actor::Preference::NULL, Actor.preferences
  end
end
