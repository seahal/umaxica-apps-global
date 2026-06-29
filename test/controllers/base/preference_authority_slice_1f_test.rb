# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class BasePreferenceAuthoritySlice1fTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_preferences, :client_token_kinds

  SURFACES = {
    app: {
      host_env: "BASE_SERVICE_URL",
      host_default: "www.app.localhost",
      preference_count: "AppPreference.count",
    },
    com: {
      host_env: "BASE_CORPORATE_URL",
      host_default: "www.com.localhost",
      preference_count: "ComPreference.count",
    },
    org: {
      host_env: "BASE_STAFF_URL",
      host_default: "www.org.localhost",
      preference_count: "OrgPreference.count",
    },
  }.freeze

  test "base preference root renders for every surface" do
    SURFACES.each do |surface, config|
      host = ENV.fetch(config.fetch(:host_env), config.fetch(:host_default))
      host! host

      get public_send("base_#{surface}_preference_url", ri: "jp", host: host)

      assert_response :success
      assert_select "[data-controller='theme']", count: 1
      assert_predicate cookies[PreferenceCookieName.access(surface: surface)], :present?
      assert_predicate cookies[PreferenceCookieName.refresh(surface: surface)], :present?
    end
  end

  test "base theme preference edit hides footer ajax theme controls for every surface" do
    SURFACES.each do |surface, config|
      host = ENV.fetch(config.fetch(:host_env), config.fetch(:host_default))
      host! host

      get public_send("edit_base_#{surface}_preference_theme_url", ri: "jp", host: host)

      assert_response :success
      assert_select "[data-controller='theme']", count: 0
      assert_select "select[name='preference_theme[option_id]']", count: 1
    end
  end

  test "base cookie preference edit renders translations for every surface" do
    SURFACES.each do |surface, config|
      host = ENV.fetch(config.fetch(:host_env), config.fetch(:host_default))
      host! host

      get public_send("edit_base_#{surface}_preference_cookie_url", ri: "jp", host: host)

      assert_response :success
      assert_no_match(/translation missing/i, response.body)
      assert_select "form[action*='/preference/cookie']", count: 1
      assert_select "input[type='checkbox'][name='preference_cookie[consented]']", count: 1
    end
  end

  test "base preference screen edit renders for every surface" do
    SURFACES.each do |surface, config|
      host = ENV.fetch(config.fetch(:host_env), config.fetch(:host_default))
      host! host

      get public_send("edit_base_#{surface}_preference_language_url", ri: "jp", lx: "en", host: host)

      assert_response :success
      assert_no_match(/id\.umaxica/, response.body)
      assert_no_match(%r{/sign/[^"]*/preference}, response.body)
      assert_match(
        %r{action="(?:https?://#{Regexp.escape(host)})?/preference/language(?:\?[^"]*)?"},
        response.body,
      )
    end
  end

  test "base preference reset edit posts to base for every surface" do
    SURFACES.each do |surface, config|
      host = ENV.fetch(config.fetch(:host_env), config.fetch(:host_default))
      host! host

      get public_send("edit_base_#{surface}_preference_reset_url", ri: "jp", host: host)

      assert_response :success
      assert_no_match(/id\.umaxica/, response.body)
      assert_no_match(%r{/sign/[^"]*/preference}, response.body)
      assert_match(
        %r{action="(?:https?://#{Regexp.escape(host)})?/preference/reset(?:\?[^"]*)?"},
        response.body,
      )
    end
  end

  test "base org preference region edit posts to base host" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    host! host

    get edit_base_org_preference_region_url(ri: "jp", host: host)

    assert_response :success
    assert_no_match(/id\.umaxica/, response.body)
    assert_no_match(%r{/sign/[^"]*/preference}, response.body)
    assert_match(
      %r{action="(?:https?://#{Regexp.escape(host)})?/preference/region(?:\?[^"]*)?"},
      response.body,
    )
  end

  test "base preference region edit renders localized region names for every surface" do
    SURFACES.each do |surface, config|
      host = ENV.fetch(config.fetch(:host_env), config.fetch(:host_default))
      host! host

      get public_send("edit_base_#{surface}_preference_region_url", ri: "jp", host: host)

      assert_response :success
      assert_select "select[name='preference_region[option_id]'] option", 2
      assert_select "select[name='preference_region[option_id]'] option[value='']", 0
      assert_select "select[name='preference_region[option_id]'] option", text: "日本"
      assert_select "select[name='preference_region[option_id]'] option", text: "アメリカ合衆国 (USA)"
      assert_select "select[name='preference_region[option_id]'] option", text: "JP", count: 0
      assert_select "select[name='preference_region[option_id]'] option", text: "US", count: 0
      assert_select "select[name='preference_region[option_id]'] option", text: "Jp", count: 0
      assert_select "select[name='preference_region[option_id]'] option", text: "Us", count: 0

      get public_send("edit_base_#{surface}_preference_region_url", ri: "us", host: host)

      assert_response :success
      assert_select "html[lang='en']"
      assert_select "h1", text: "Region & Language Settings"
      assert_select "select[name='preference_region[option_id]'] option", text: "United States - USA"
      assert_select "select[name='preference_region[option_id]'] option", text: "Japan - 日本"
      assert_select "select[name='preference_region[option_id]'] option", text: "US", count: 0
      assert_select "select[name='preference_region[option_id]'] option", text: "JP", count: 0
      assert_select "select[name='preference_region[option_id]'] option", text: "English", count: 0
    end
  end

  test "base org preference timezone edit posts to base host" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    host! host

    get edit_base_org_preference_timezone_url(ri: "jp", host: host)

    assert_response :success
    assert_no_match(/id\.umaxica/, response.body)
    assert_no_match(%r{/sign/[^"]*/preference}, response.body)
    assert_match(
      %r{action="(?:https?://#{Regexp.escape(host)})?/preference/timezone(?:\?[^"]*)?"},
      response.body,
    )
  end

  test "base app preference timezone edit renders localized timezone option labels" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host

    get edit_base_app_preference_timezone_url(ri: "us", lx: "ja", host: host)

    assert_response :success
    assert_select "select[name='preference_timezone[option_id]'] option", text: "協定世界時 (UTC)"
    assert_select "select[name='preference_timezone[option_id]'] option", text: "日本標準時 (Asia/Tokyo)"
    assert_select "select[name='preference_timezone[option_id]'] option", text: "Etc/UTC", count: 0
    assert_select "select[name='preference_timezone[option_id]'] option", text: "Asia/Tokyo", count: 0

    get edit_base_app_preference_timezone_url(ri: "us", lx: "en", host: host)

    assert_response :success
    assert_select "html[lang='en']"
    assert_select "select[name='preference_timezone[option_id]'] option", text: "Coordinated Universal Time (UTC)"
    assert_select "select[name='preference_timezone[option_id]'] option", text: "Japan Standard Time (Asia/Tokyo)"
  end

  test "base preference write updates app user preference" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    patch base_app_preference_theme_url(host: host),
          params: { preference_theme: { option_id: "dr" } },
          headers: session_headers(host, token, user),
          as: :json

    assert_response :ok
    assert_equal "dr", response.parsed_body.dig("preference", "ct")
    assert_equal "dr", user.user_preference.reload.theme
  end

  test "base preference reset remains destructive and removes app user preference" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    user.user_preference.update!(theme: "dr")

    delete base_app_preference_reset_url(host: host),
           params: { confirm_reset: "1" },
           headers: session_headers(host, token, user)

    assert_redirected_to base_app_preference_url(host: host)
    assert_nil user.reload.user_preference
  end

  private

  def session_headers(host, token, user)
    {
      "Host" => host,
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end
end
