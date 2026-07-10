# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceWebCsrfTest < ActionDispatch::IntegrationTest
  test "app web preference PATCH endpoints reject missing CSRF token" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))

    patch(base_app_web_v0_theme_path, params: { theme: "dark" }, headers: { "Accept" => "application/json" }, as: :json)

    assert_response :forbidden

    patch(
      base_app_web_v0_cookie_path, params: { consented: true }, headers: { "Accept" => "application/json" },
                                   as: :json,
    )

    assert_response :forbidden
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "com web preference PATCH endpoints reject missing CSRF token" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    host!(ENV.fetch("PUBLIC_BASE_CORPORATE_URL"))

    patch(base_com_web_v0_theme_path, params: { theme: "dark" }, headers: { "Accept" => "application/json" }, as: :json)

    assert_response :forbidden

    patch(
      base_com_web_v0_cookie_path, params: { consented: true }, headers: { "Accept" => "application/json" },
                                   as: :json,
    )

    assert_response :forbidden
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "org web preference PATCH endpoints reject missing CSRF token" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    host!(ENV.fetch("PUBLIC_BASE_STAFF_URL"))

    patch(base_org_web_v0_theme_path, params: { theme: "dark" }, headers: { "Accept" => "application/json" }, as: :json)

    assert_response :forbidden

    patch(
      base_org_web_v0_cookie_path, params: { consented: true }, headers: { "Accept" => "application/json" },
                                   as: :json,
    )

    assert_response :forbidden
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "same-origin strict-mode POST reaches app controller without a CSRF rejection" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host!(host)

    patch(
      base_app_web_v0_theme_path,
      params: { theme: "dark" },
      headers: {
        "Accept" => "application/json",
        "Origin" => "http://#{host}",
        "Sec-Fetch-Site" => "same-origin",
      },
      as: :json,
    )

    assert_not_equal I18n.t("errors.invalid_authenticity_token"), response.parsed_body["error"]
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "same-site strict-mode POST reaches allowed base surfaces without a CSRF rejection" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    [
      [ENV.fetch("PUBLIC_BASE_SERVICE_URL"), base_app_web_v0_theme_path],
      [ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), base_com_web_v0_theme_path],
      [ENV.fetch("PUBLIC_BASE_STAFF_URL"), base_org_web_v0_theme_path],
    ].each do |host, path|
      host!(host)
      patch(
        path,
        params: { theme: "dark" },
        headers: {
          "Accept" => "application/json",
          "Origin" => "http://#{host}",
          "Sec-Fetch-Site" => "same-site",
        },
        as: :json,
      )

      assert_not_equal 403, response.status
    end
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "cross-site POST from untrusted origin is forbidden" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host!(host)

    patch(
      base_app_web_v0_theme_path,
      params: { theme: "dark" },
      headers: {
        "Accept" => "application/json",
        "Origin" => "https://evil.example",
        "Sec-Fetch-Site" => "cross-site",
      },
      as: :json,
    )

    assert_response :forbidden
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "cross-site POST rejects trusted-origin suffix scheme and port confusion" do
    original = ActionController::Base.allow_forgery_protection
    original_trusted_origins = Base::App::ApplicationController.forgery_protection_trusted_origins
    ActionController::Base.allow_forgery_protection = true
    Base::App::ApplicationController.forgery_protection_trusted_origins = [
      "https://#{ENV.fetch("PUBLIC_BASE_SERVICE_URL")}",
      "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
    ]

    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host!(host)

    [
      "https://#{host}.evil.example",
      "http://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
      "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}:444",
    ].each do |origin|
      patch(
        base_app_web_v0_theme_path,
        params: { theme: "dark" },
        headers: {
          "Accept" => "application/json",
          "Origin" => origin,
          "Sec-Fetch-Site" => "cross-site",
        },
        as: :json,
      )

      assert_response :forbidden, origin
    end
  ensure
    ActionController::Base.allow_forgery_protection = original
    Base::App::ApplicationController.forgery_protection_trusted_origins = original_trusted_origins
  end

  test "cross-site POST from trusted auth origin is allowed" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host!(host)

    patch(
      base_app_web_v0_theme_path,
      params: { theme: "dark" },
      headers: {
        "Accept" => "application/json",
        "Origin" => Base::App::ApplicationController.forgery_protection_trusted_origins.grep(/auth/).first,
        "Sec-Fetch-Site" => "cross-site",
      },
      as: :json,
    )

    assert_not_equal 403, response.status
    assert_not_equal I18n.t("errors.invalid_authenticity_token"), response.parsed_body["error"]
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "trusted app auth origin cross-site POST passes with a real session-bound token" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host!(host)

    user = Client.first
    session_record = ClientToken.create!(
      user: user,
      user_token_status_id: ClientTokenStatus::NOTHING,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      public_id: "csrf_#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
    )
    auth_headers = {
      "Accept" => "text/html",
      "Authorization" => "Bearer #{jwt_access_token_for(
        user, host: host, session_public_id: session_record.public_id, resource_type: "client",
      )}",
      "X-TEST-SESSION-PUBLIC-ID" => session_record.public_id,
    }

    get(base_app_identity_emails_path(ri: "jp"), headers: auth_headers)

    assert_response :success
    token = response.body[/name="csrf-token" content="([^"]+)"/, 1]
    cookies["csrf_token"] = token

    assert_predicate token, :present?

    patch(
      base_app_web_v0_theme_path(ri: "jp"),
      params: { theme: "dark" },
      headers: {
        "Accept" => "application/json",
        "Origin" => Base::App::ApplicationController.forgery_protection_trusted_origins.grep(/auth/).first,
        "Sec-Fetch-Site" => "cross-site",
        "X-CSRF-Token" => token,
      },
      as: :json,
    )

    assert_not_equal I18n.t("errors.invalid_authenticity_token"), response.parsed_body["error"]
    assert_not_equal 403, response.status
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "missing Sec-Fetch-Site remains fail-closed without a Rails session-bound token" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    token = "legacy-csrf-token"
    cookies["csrf_token"] = token
    host!(host)

    patch(
      base_app_web_v0_theme_path,
      params: { theme: "dark" },
      headers: {
        "Accept" => "application/json",
        "Origin" => "https://#{host}",
        "X-CSRF-Token" => token,
      },
      as: :json,
    )

    assert_response :forbidden
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "missing Sec-Fetch-Site legacy fallback passes only with the same session-bound token" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host!(host)

    user = Client.first
    session_record = ClientToken.create!(
      user: user,
      user_token_status_id: ClientTokenStatus::NOTHING,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      public_id: "csrf_#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
    )
    auth_headers = {
      "Accept" => "text/html",
      "Authorization" => "Bearer #{jwt_access_token_for(
        user, host: host, session_public_id: session_record.public_id, resource_type: "client",
      )}",
      "X-TEST-SESSION-PUBLIC-ID" => session_record.public_id,
    }

    get(base_app_identity_emails_path(ri: "jp"), headers: auth_headers)

    assert_response :success
    token = response.body[/name="csrf-token" content="([^"]+)"/, 1]
    cookies["csrf_token"] = token

    assert_predicate token, :present?

    patch(
      base_app_web_v0_theme_path(ri: "jp"),
      params: { theme: "dark" },
      headers: {
        "Accept" => "application/json",
        "Origin" => "https://#{host}",
        "X-CSRF-Token" => token,
      },
      as: :json,
    )

    assert_not_equal 403, response.status

    second_session = open_session
    second_session.host!(host)
    second_session.patch(
      base_app_web_v0_theme_path(ri: "jp"),
      params: { theme: "dark" },
      headers: {
        "Accept" => "application/json",
        "Origin" => "https://#{host}",
        "X-CSRF-Token" => token,
      },
      as: :json,
    )

    assert_equal 403, second_session.response.status

    patch(
      base_app_web_v0_theme_path(ri: "jp"),
      params: { theme: "dark" },
      headers: {
        "Accept" => "application/json",
        "Origin" => "https://#{host}",
        "X-CSRF-Token" => "invalid-token",
      },
      as: :json,
    )

    assert_response :forbidden

    patch(
      base_app_web_v0_theme_path(ri: "jp"),
      params: { theme: "dark" },
      headers: {
        "Accept" => "application/json",
        "Origin" => "https://#{host}",
      },
      as: :json,
    )

    assert_response :forbidden
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "protocol exception endpoints remain tokenless but protected by protocol-specific guards" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
    post(
      base_app_oauth_token_path,
      params: { grant_type: "client_credentials" },
      headers: { "Accept" => "application/json", "Sec-Fetch-Site" => "cross-site" },
      as: :json,
    )

    assert_not_equal 403, response.status

    post(
      auth_app_oidc_backchannel_logout_url(host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL")),
      params: { logout_token: "invalid" },
      headers: { "Accept" => "application/json", "Sec-Fetch-Site" => "cross-site" },
      as: :json,
    )

    assert_not_equal 403, response.status
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
