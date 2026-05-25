# typed: false
# frozen_string_literal: true

require "test_helper"

class JumpToControllerTest < ActionDispatch::IntegrationTest
  MODERN_UA =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) " \
    "Chrome/120.0.0.0 Safari/537.36"

  setup do
    @original_jump_allowed_hosts = ENV["JUMP_ALLOWED_HOSTS"]
    [AppJumpLink, ComJumpLink, OrgJumpLink].each(&:delete_all)
    ENV["JUMP_ALLOWED_HOSTS"] = "outside.example"
  end

  teardown do
    if @original_jump_allowed_hosts.nil?
      ENV.delete("JUMP_ALLOWED_HOSTS")
    else
      ENV["JUMP_ALLOWED_HOSTS"] = @original_jump_allowed_hosts
    end
  end

  test "app host routes to app jump link and redirects off host" do
    link = AppJumpLink.create!(destination_url: "https://outside.example/app")

    host! normalized_jump_host("JUMP_SERVICE_URL", "jump.app.localhost")
    get "/", params: { to: link.public_id }, headers: { "Client-Agent" => MODERN_UA }

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

    host! normalized_jump_host("JUMP_CORPORATE_URL", "jump.com.localhost")
    get "/", params: { to: app_link.public_id }, headers: { "Client-Agent" => MODERN_UA }

    assert_response :redirect

    assert_redirected_to com_link.destination_url
    assert_equal 0, app_link.reload.uses_count
    assert_equal 1, com_link.reload.uses_count
  end

  test "org host routes to org jump link only" do
    com_link = ComJumpLink.create!(public_id: "B" * 21, destination_url: "https://outside.example/com")
    org_link = OrgJumpLink.create!(public_id: "B" * 21, destination_url: "https://outside.example/org")

    host! normalized_jump_host("JUMP_STAFF_URL", "jump.org.localhost")
    get "/", params: { to: org_link.public_id }, headers: { "Client-Agent" => MODERN_UA }

    assert_response :redirect

    assert_redirected_to org_link.destination_url
    assert_equal 0, com_link.reload.uses_count
    assert_equal 1, org_link.reload.uses_count
  end

  test "missing to param renders landing page" do
    host! normalized_jump_host("JUMP_SERVICE_URL", "jump.app.localhost")
    get "/", headers: { "Client-Agent" => MODERN_UA }

    assert_response :success
    assert_select "title", "UMAXICA (app) | Jump"
    assert_select "h1", "UMAXICA (app) | Jump"
  end

  test "empty to param renders landing page" do
    host! normalized_jump_host("JUMP_SERVICE_URL", "jump.app.localhost")
    get "/", params: { to: "" }, headers: { "Client-Agent" => MODERN_UA }

    assert_response :success
    assert_select "title", "UMAXICA (app) | Jump"
    assert_select "h1", "UMAXICA (app) | Jump"
  end

  test "missing or unavailable public id returns not found with plain text body" do
    host! normalized_jump_host("JUMP_SERVICE_URL", "jump.app.localhost")
    get "/", params: { to: "missing" }, headers: { "Client-Agent" => MODERN_UA }

    assert_response :not_found
    assert_match %r{\Atext/plain}, response.content_type
    assert_equal I18n.t("jump.redirector.unavailable"), response.body
  end

  test "rejects destination host outside jump allowlist" do
    link = AppJumpLink.create!(destination_url: "https://evil.example/path")

    host! normalized_jump_host("JUMP_SERVICE_URL", "jump.app.localhost")
    get "/", params: { to: link.public_id }, headers: { "Client-Agent" => MODERN_UA }

    assert_response :not_found
    assert_equal 1, link.reload.uses_count
  end

  test "rejects destination with non-http scheme" do
    link = AppJumpLink.create!(destination_url: "javascript:alert(1)")

    host! normalized_jump_host("JUMP_SERVICE_URL", "jump.app.localhost")
    get "/", params: { to: link.public_id }, headers: { "Client-Agent" => MODERN_UA }

    assert_response :not_found
  end

  test "rejects destination with userinfo" do
    link = AppJumpLink.create!(destination_url: "https://user:secret@outside.example/path")

    host! normalized_jump_host("JUMP_SERVICE_URL", "jump.app.localhost")
    get "/", params: { to: link.public_id }, headers: { "Client-Agent" => MODERN_UA }

    assert_response :not_found
  end

  test "rejects subdomain of configured host" do
    link = AppJumpLink.create!(destination_url: "https://sub.outside.example/path")

    host! normalized_jump_host("JUMP_SERVICE_URL", "jump.app.localhost")
    get "/", params: { to: link.public_id }, headers: { "Client-Agent" => MODERN_UA }

    assert_response :not_found
  end

  test "allows configured host with explicit non-default port" do
    ENV["JUMP_ALLOWED_HOSTS"] = "outside.example:8443"
    link = AppJumpLink.create!(destination_url: "https://outside.example:8443/app")

    host! normalized_jump_host("JUMP_SERVICE_URL", "jump.app.localhost")
    get "/", params: { to: link.public_id }, headers: { "Client-Agent" => MODERN_UA }

    assert_response :redirect
    assert_redirected_to "https://outside.example:8443/app"
  end

  test "route generation uses root with query param" do
    assert_equal "/?to=opaque123", jump_app_root_path(to: "opaque123")
  end

  test "root controllers use the expected jump link models" do
    assert_equal AppJumpLink, Jump::App::RootsController::JUMP_LINK_MODEL
    assert_equal ComJumpLink, Jump::Com::RootsController::JUMP_LINK_MODEL
    assert_equal OrgJumpLink, Jump::Org::RootsController::JUMP_LINK_MODEL
  end

  def normalized_jump_host(env_key, fallback)
    Common::Redirect.normalize_host(ENV.fetch(env_key, fallback))
  end
end
