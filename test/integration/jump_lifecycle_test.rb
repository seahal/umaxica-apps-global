# typed: false
# frozen_string_literal: true

require "test_helper"

class JumpLifecycleTest < ActionDispatch::IntegrationTest
  setup do
    @original_jump_allowed_hosts = ENV["JUMP_ALLOWED_HOSTS"]
    ENV["JUMP_ALLOWED_HOSTS"] = "example.com"
    Actor.reset
  end

  teardown do
    if @original_jump_allowed_hosts.nil?
      ENV.delete("JUMP_ALLOWED_HOSTS")
    else
      ENV["JUMP_ALLOWED_HOSTS"] = @original_jump_allowed_hosts
    end
    Actor.reset
  end

  test "app jump host renders landing page without Actor surface state" do
    host! ENV.fetch("JUMP_APP_URL", "app.localhost")

    get "/"

    assert_response :success
    assert_select "title", "UMAXICA (app) | Jump"
    assert_nil Actor.surface
  end

  test "com jump host renders landing page without Actor surface state" do
    host! ENV.fetch("JUMP_COM_URL", "com.localhost")

    get "/"

    assert_response :success
    assert_select "title", "UMAXICA (com) | Jump"
    assert_nil Actor.surface
  end

  test "org jump host renders landing page without Actor surface state" do
    host! ENV.fetch("JUMP_ORG_URL", "org.localhost")

    get "/"

    assert_response :success
    assert_select "title", "UMAXICA (org) | Jump"
    assert_nil Actor.surface
  end

  test "Actor remains reset after the response" do
    host! ENV.fetch("JUMP_APP_URL", "app.localhost")

    get "/"

    assert_nil Actor.surface
    assert_nil Actor.domain
    assert_equal :unauthenticated, Actor.actor_type
  end

  test "existing redirect success still works" do
    host! ENV.fetch("JUMP_APP_URL", "app.localhost")
    link = AppJumpLink.create!(
      destination_url: "https://example.com/destination",
      public_id: "A#{SecureRandom.alphanumeric(20)}",
    )

    get "/", params: { to: link.public_id }

    assert_redirected_to link.destination_url
  end

  test "existing redirect failure (not found) still works" do
    host! ENV.fetch("JUMP_APP_URL", "app.localhost")

    get "/", params: { to: "non-existent-id" }

    assert_response :not_found
  end

  test "cookie session skip behavior still applies" do
    host! ENV.fetch("JUMP_APP_URL", "app.localhost")

    get "/"

    # Jump endpoints should not set session cookies
    # The Set-Cookie header should not contain session-related cookies
    set_cookie_header = response.headers["Set-Cookie"]

    assert_nil set_cookie_header
    if set_cookie_header.present?
      assert_no_match(/session/i, set_cookie_header, "Jump should not set session cookies")
    end
  end
end
