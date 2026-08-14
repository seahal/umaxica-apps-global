# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SurfaceRootsControllerTest < ActionDispatch::IntegrationTest
  # The base gateway hosts no longer serve a page at `/`. They canonicalize to the regional root
  # for the requested region, normalizing a missing region first.
  test "acme app root normalizes the region then permanently redirects to the regional root" do
    get "/", headers: { "Host" => ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost") }

    assert_response :found
    follow_redirect!

    assert_response :moved_permanently
    assert_equal "https://jp.umaxica.app/", response.location
  end

  test "acme app www root permanently redirects to the regional root with ri parameter" do
    get "/?ri=jp", headers: { "Host" => ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost") }

    assert_response :moved_permanently
    assert_equal "https://jp.umaxica.app/", response.location
  end

  test "acme com root normalizes the region then permanently redirects to the regional root" do
    get "/", headers: { "Host" => ENV.fetch("PRIVATE_BASE_CORPORATE_URL", "www.com.localhost") }
    follow_redirect! if response.redirect? && response.status == 302

    assert_response :moved_permanently
    assert_equal "https://jp.umaxica.com/", response.location
  end

  test "acme org root normalizes the region then permanently redirects to the regional root" do
    get "/", headers: { "Host" => ENV.fetch("PRIVATE_BASE_STAFF_URL", "www.org.localhost") }
    follow_redirect! if response.redirect? && response.status == 302

    assert_response :moved_permanently
    assert_equal "https://jp.umaxica.org/", response.location
  end

  test "acme org www root permanently redirects to the regional root with ri parameter" do
    get "/?ri=jp", headers: { "Host" => ENV.fetch("PRIVATE_BASE_STAFF_URL", "www.org.localhost") }

    assert_response :moved_permanently
    assert_equal "https://jp.umaxica.org/", response.location
  end
end

class SurfaceHealthEndpointTest < ActionDispatch::IntegrationTest
  test "acme app health responds successfully" do
    get "/health", headers: { "Host" => ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost") }
    follow_redirect! if response.redirect?

    assert_response :success
  end

  test "acme com health responds successfully" do
    get "/health", headers: { "Host" => ENV.fetch("PRIVATE_BASE_CORPORATE_URL", "www.com.localhost") }
    follow_redirect! if response.redirect?

    assert_response :success
  end

  test "acme org health responds successfully" do
    get "/health", headers: { "Host" => ENV.fetch("PRIVATE_BASE_STAFF_URL", "www.org.localhost") }
    follow_redirect! if response.redirect?

    assert_response :success
  end

  test "sign app health responds successfully" do
    get "/health", headers: { "Host" => ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost") }
    follow_redirect! if response.redirect?

    assert_response :success
  end

  test "sign org health responds successfully" do
    get "/health", headers: { "Host" => ENV.fetch("PRIVATE_AUTH_STAFF_URL", "sign.org.localhost") }
    follow_redirect! if response.redirect?

    assert_response :success
  end
end
