# typed: false
# frozen_string_literal: true

require "test_helper"

class SurfaceRootsControllerTest < ActionDispatch::IntegrationTest
  test "apex app root responds successfully" do
    get "/", headers: { "Host" => "app.localhost" }
    follow_redirect! if response.redirect?

    assert_response :success
  end

  test "apex com root responds successfully" do
    get "/", headers: { "Host" => "com.localhost" }
    follow_redirect! if response.redirect?

    assert_response :success
  end

  test "apex org root responds successfully" do
    get "/", headers: { "Host" => "org.localhost" }
    follow_redirect! if response.redirect?

    assert_response :success
  end
end

class SurfaceHealthControllerTest < ActionDispatch::IntegrationTest
  test "apex app health responds successfully" do
    get "/health", headers: { "Host" => "app.localhost" }
    follow_redirect! if response.redirect?

    assert_response :success
  end

  test "apex com health responds successfully" do
    get "/health", headers: { "Host" => "com.localhost" }
    follow_redirect! if response.redirect?

    assert_response :success
  end

  test "apex org health responds successfully" do
    get "/health", headers: { "Host" => "org.localhost" }
    follow_redirect! if response.redirect?

    assert_response :success
  end

  test "sign app health responds successfully" do
    get "/health", headers: { "Host" => "id.app.localhost" }
    follow_redirect! if response.redirect?

    assert_response :success
  end

  test "sign org health responds successfully" do
    get "/health", headers: { "Host" => "id.org.localhost" }
    follow_redirect! if response.redirect?

    assert_response :success
  end
end
