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

  test "app jump host renders landing page without Actor tld state" do
    host! ENV.fetch("JUMP_APP_URL", "jump.app.localhost")

    get "/", params: { ri: "jp" }

    assert_response :success
    assert_select "title", "UMAXICA (app) | Jump"
    assert_nil Actor.tld
  end

  test "com jump host renders landing page without Actor tld state" do
    host! ENV.fetch("JUMP_COM_URL", "jump.com.localhost")

    get "/", params: { ri: "jp" }

    assert_response :success
    assert_select "title", "UMAXICA (com) | Jump"
    assert_nil Actor.tld
  end

  test "org jump host renders landing page without Actor tld state" do
    host! ENV.fetch("JUMP_ORG_URL", "jump.org.localhost")

    get "/", params: { ri: "jp" }

    assert_response :success
    assert_select "title", "UMAXICA (org) | Jump"
    assert_nil Actor.tld
  end

  test "Actor remains reset after the response" do
    host! ENV.fetch("JUMP_APP_URL", "jump.app.localhost")

    get "/", params: { ri: "jp" }

    assert_nil Actor.tld
    assert_equal :unauthenticated, Actor.actor_type
  end

  test "existing redirect success still works" do
    host! ENV.fetch("JUMP_APP_URL", "jump.app.localhost")
    link = AppJumpLink.create!(
      destination_url: "https://example.com/destination",
      public_id: "A#{SecureRandom.alphanumeric(20)}",
    )

    get "/", params: { ri: "jp", to: link.public_id }

    assert_redirected_to link.destination_url
  end

  test "existing redirect failure (not found) still works" do
    host! ENV.fetch("JUMP_APP_URL", "jump.app.localhost")

    get "/", params: { ri: "jp", to: "non-existent-id" }

    assert_response :not_found
  end

  test "cookie session skip behavior still applies" do
    host! ENV.fetch("JUMP_APP_URL", "jump.app.localhost")

    get "/", params: { ri: "jp" }

    # Jump endpoints should not set session cookies
    # The Set-Cookie header should not contain session-related cookies
    set_cookie_header = response.headers["Set-Cookie"]
    combined = Array(set_cookie_header).join("\n")

    assert_no_match(/session/i, combined, "Jump should not set session cookies")
  end
end
