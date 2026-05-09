# typed: false
# frozen_string_literal: true

require "test_helper"

class JumpToControllerTest < ActionDispatch::IntegrationTest
  MODERN_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

  setup do
    [AppJumpLink, ComJumpLink, OrgJumpLink].each(&:delete_all)
    ENV["JUMP_ALLOWED_HOSTS"] = "outside.example"
  end

  test "app host routes to app jump link and redirects off host" do
    link = AppJumpLink.create!(destination_url: "https://outside.example/app")

    host! ENV["JUMP_SERVICE_URL"]
    get "/", params: { to: link.public_id }, headers: { "User-Agent" => MODERN_UA }

    assert_response :redirect

    assert_redirected_to "https://outside.example/app"
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    assert_equal 1, link.reload.uses_count
    assert_equal "/", request.path
    assert_not_includes request.fullpath, link.destination_url
  end

  test "com host routes to com jump link only" do
    app_link = AppJumpLink.create!(public_id: "A" * 21, destination_url: "https://outside.example/app")
    com_link = ComJumpLink.create!(public_id: "A" * 21, destination_url: "https://outside.example/com")

    host! ENV["JUMP_CORPORATE_URL"]
    get "/", params: { to: app_link.public_id }, headers: { "User-Agent" => MODERN_UA }

    assert_response :redirect

    assert_redirected_to com_link.destination_url
    assert_equal 0, app_link.reload.uses_count
    assert_equal 1, com_link.reload.uses_count
  end

  test "org host routes to org jump link only" do
    com_link = ComJumpLink.create!(public_id: "B" * 21, destination_url: "https://outside.example/com")
    org_link = OrgJumpLink.create!(public_id: "B" * 21, destination_url: "https://outside.example/org")

    host! ENV["JUMP_STAFF_URL"]
    get "/", params: { to: org_link.public_id }, headers: { "User-Agent" => MODERN_UA }

    assert_response :redirect

    assert_redirected_to org_link.destination_url
    assert_equal 0, com_link.reload.uses_count
    assert_equal 1, org_link.reload.uses_count
  end

  test "missing to param returns not found with plain text body" do
    host! ENV["JUMP_SERVICE_URL"]
    get "/", headers: { "User-Agent" => MODERN_UA }

    assert_response :not_found
    assert_match %r{\Atext/plain}, response.content_type
    assert_equal I18n.t("jump.redirector.unavailable"), response.body
  end

  test "empty to param returns not found with plain text body" do
    host! ENV["JUMP_SERVICE_URL"]
    get "/", params: { to: "" }, headers: { "User-Agent" => MODERN_UA }

    assert_response :not_found
    assert_match %r{\Atext/plain}, response.content_type
    assert_equal I18n.t("jump.redirector.unavailable"), response.body
  end

  test "missing or unavailable public id returns not found with plain text body" do
    host! ENV["JUMP_SERVICE_URL"]
    get "/", params: { to: "missing" }, headers: { "User-Agent" => MODERN_UA }

    assert_response :not_found
    assert_match %r{\Atext/plain}, response.content_type
    assert_equal I18n.t("jump.redirector.unavailable"), response.body
  end

  test "route generation uses root with query param" do
    assert_equal "/?to=opaque123", jump_app_root_path(to: "opaque123")
  end
end
