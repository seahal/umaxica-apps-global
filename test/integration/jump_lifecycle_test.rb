# typed: false
# frozen_string_literal: true

require "test_helper"

class JumpLifecycleTest < ActionDispatch::IntegrationTest
  setup do
    Jumper.reset
  end

  teardown do
    Jumper.reset
  end

  test "app jump host is routed and resets Jumper.domain" do
    host! ENV.fetch("JUMP_APP_URL", "app.localhost")

    get "/", params: { to: "test-link" }

    assert_response :not_found
    assert_nil Jumper.domain
  end

  test "com jump host is routed and resets Jumper.domain" do
    host! ENV.fetch("JUMP_COM_URL", "com.localhost")

    get "/", params: { to: "test-link" }

    assert_response :not_found
    assert_nil Jumper.domain
  end

  test "org jump host is routed and resets Jumper.domain" do
    host! ENV.fetch("JUMP_ORG_URL", "org.localhost")

    get "/", params: { to: "test-link" }

    assert_response :not_found
    assert_nil Jumper.domain
  end

  test "Jumper is reset after the response" do
    host! ENV.fetch("JUMP_APP_URL", "app.localhost")

    get "/", params: { to: "test-link" }

    # Jumper should be reset after the request completes
    assert_nil Jumper.domain
    assert_equal :unauthenticated, Jumper.actor_type
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

    get "/", params: { to: "test-link" }

    # Jump endpoints should not set session cookies
    # The Set-Cookie header should not contain session-related cookies
    set_cookie_header = response.headers["Set-Cookie"]

    assert_nil set_cookie_header
    if set_cookie_header.present?
      assert_no_match(/session/i, set_cookie_header, "Jump should not set session cookies")
    end
  end
end
