# typed: false
# frozen_string_literal: true

require "test_helper"

class SurfaceRootsControllerTest < ActionDispatch::IntegrationTest
  test "acme app root responds successfully" do
    get "/", headers: { "Host" => ENV.fetch("ACME_SERVICE_URL", "www.app.localhost") }
    follow_redirect! if response.redirect?

    assert_response :success
  end

  test "acme app www root responds successfully with ri parameter" do
    get "/?ri=jp", headers: { "Host" => ENV.fetch("ACME_SERVICE_URL", "www.app.localhost") }
    follow_redirect! if response.redirect?

    assert_response :success
  end

  test "acme com root responds successfully" do
    get "/", headers: { "Host" => ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost") }
    follow_redirect! if response.redirect?

    assert_response :success
  end

  test "acme org root responds successfully" do
    get "/", headers: { "Host" => ENV.fetch("ACME_STAFF_URL", "www.org.localhost") }
    follow_redirect! if response.redirect?

    assert_response :success
  end

  test "acme org www root responds successfully with ri parameter" do
    get "/?ri=jp", headers: { "Host" => ENV.fetch("ACME_STAFF_URL", "www.org.localhost") }
    follow_redirect! if response.redirect?

    assert_response :success
  end
end

class SurfaceHealthEndpointTest < ActionDispatch::IntegrationTest
  test "acme app health responds successfully" do
    get "/health", headers: { "Host" => ENV.fetch("ACME_SERVICE_URL", "www.app.localhost") }
    follow_redirect! if response.redirect?

    assert_response :success
  end

  test "acme com health responds successfully" do
    get "/health", headers: { "Host" => ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost") }
    follow_redirect! if response.redirect?

    assert_response :success
  end

  test "acme org health responds successfully" do
    get "/health", headers: { "Host" => ENV.fetch("ACME_STAFF_URL", "www.org.localhost") }
    follow_redirect! if response.redirect?

    assert_response :success
  end

  test "sign app health responds successfully" do
    get "/health", headers: { "Host" => ENV.fetch("SIGN_SERVICE_URL", "log.umaxica.app") }
    follow_redirect! if response.redirect?

    assert_response :success
  end

  test "sign org health responds successfully" do
    get "/health", headers: { "Host" => ENV.fetch("SIGN_STAFF_URL", "log.umaxica.org") }
    follow_redirect! if response.redirect?

    assert_response :success
  end
end
