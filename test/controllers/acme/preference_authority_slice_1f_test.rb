# typed: false
# frozen_string_literal: true

require "test_helper"

class AcmePreferenceAuthoritySlice1fTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_preferences, :client_token_kinds

  SURFACES = {
    app: {
      host_env: "ACME_SERVICE_URL",
      host_default: "www.app.localhost",
      preference_count: "AppPreference.count",
    },
    com: {
      host_env: "ACME_CORPORATE_URL",
      host_default: "www.com.localhost",
      preference_count: "ComPreference.count",
    },
    org: {
      host_env: "ACME_STAFF_URL",
      host_default: "www.org.localhost",
      preference_count: "OrgPreference.count",
    },
  }.freeze

  test "acme preference root renders for every surface" do
    SURFACES.each do |surface, config|
      host = ENV.fetch(config.fetch(:host_env), config.fetch(:host_default))
      host! host

      get public_send("acme_#{surface}_preference_url", ri: "jp", host: host)

      assert_response :success
      assert_select "[data-controller='theme']", count: 1
      assert_predicate cookies[Preference::CookieName.access(surface: surface)], :present?
      assert_predicate cookies[Preference::CookieName.refresh(surface: surface)], :present?
    end
  end

  test "acme theme preference edit hides footer ajax theme controls for every surface" do
    SURFACES.each do |surface, config|
      host = ENV.fetch(config.fetch(:host_env), config.fetch(:host_default))
      host! host

      get public_send("edit_acme_#{surface}_preference_theme_url", ri: "jp", host: host)

      assert_response :success
      assert_select "[data-controller='theme']", count: 0
      assert_select "select[name='preference_theme[option_id]']", count: 1
    end
  end

  test "acme cookie preference edit renders translations for every surface" do
    SURFACES.each do |surface, config|
      host = ENV.fetch(config.fetch(:host_env), config.fetch(:host_default))
      host! host

      get public_send("edit_acme_#{surface}_preference_cookie_url", ri: ["jp", "jp"], host: host)

      assert_response :success
      assert_no_match(/translation missing/i, response.body)
      assert_select "form[action*='/preference/cookie']", count: 1
      assert_select "input[type='checkbox'][name='preference_cookie[consented]']", count: 1
    end
  end

  test "acme preference screen edit renders for every surface" do
    SURFACES.each do |surface, config|
      host = ENV.fetch(config.fetch(:host_env), config.fetch(:host_default))
      host! host

      get public_send("edit_acme_#{surface}_preference_language_url", ri: "jp", lx: "en", host: host)

      assert_response :success
      assert_no_match(/id\.umaxica/, response.body)
      assert_no_match(%r{/sign/[^"]*/preference}, response.body)
      assert_match(
        %r{action="(?:https?://#{Regexp.escape(host)})?/preference/language(?:\?[^"]*)?"},
        response.body,
      )
    end
  end

  test "acme preference reset edit posts to acme for every surface" do
    SURFACES.each do |surface, config|
      host = ENV.fetch(config.fetch(:host_env), config.fetch(:host_default))
      host! host

      get public_send("edit_acme_#{surface}_preference_reset_url", ri: "jp", host: host)

      assert_response :success
      assert_no_match(/id\.umaxica/, response.body)
      assert_no_match(%r{/sign/[^"]*/preference}, response.body)
      assert_match(
        %r{action="(?:https?://#{Regexp.escape(host)})?/preference/reset(?:\?[^"]*)?"},
        response.body,
      )
    end
  end

  test "acme org preference region edit posts to acme host" do
    host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    host! host

    get edit_acme_org_preference_region_url(ri: "jp", host: host)

    assert_response :success
    assert_no_match(/id\.umaxica/, response.body)
    assert_no_match(%r{/sign/[^"]*/preference}, response.body)
    assert_match(
      %r{action="(?:https?://#{Regexp.escape(host)})?/preference/region(?:\?[^"]*)?"},
      response.body,
    )
  end

  test "acme preference region edit renders JP and US only for every surface" do
    SURFACES.each do |surface, config|
      host = ENV.fetch(config.fetch(:host_env), config.fetch(:host_default))
      host! host

      get public_send("edit_acme_#{surface}_preference_region_url", ri: "jp", host: host)

      assert_response :success
      assert_select "select[name='preference_region[option_id]'] option", 2
      assert_select "select[name='preference_region[option_id]'] option[value='']", 0
      assert_select "select[name='preference_region[option_id]'] option", text: "JP"
      assert_select "select[name='preference_region[option_id]'] option", text: "US"
      assert_select "select[name='preference_region[option_id]'] option", text: "Jp", count: 0
      assert_select "select[name='preference_region[option_id]'] option", text: "Us", count: 0
    end
  end

  test "acme org preference timezone edit posts to acme host" do
    host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    host! host

    get edit_acme_org_preference_timezone_url(ri: "jp", host: host)

    assert_response :success
    assert_no_match(/id\.umaxica/, response.body)
    assert_no_match(%r{/sign/[^"]*/preference}, response.body)
    assert_match(
      %r{action="(?:https?://#{Regexp.escape(host)})?/preference/timezone(?:\?[^"]*)?"},
      response.body,
    )
  end

  test "acme preference write updates app user preference" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    host! host
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    patch acme_app_preference_theme_url(host: host),
          params: { preference_theme: { option_id: "dr" } },
          headers: session_headers(host, token, user),
          as: :json

    assert_response :ok
    assert_equal "dr", response.parsed_body.dig("preference", "ct")
    assert_equal "dr", user.user_preference.reload.theme
  end

  test "acme preference reset remains destructive and resets app user preference" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    host! host
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    user.user_preference.update!(theme: "dr")

    delete acme_app_preference_reset_url(host: host),
           params: { confirm_reset: "1" },
           headers: session_headers(host, token, user)

    assert_redirected_to acme_app_preference_url(host: host)
    assert_equal "sy", user.user_preference.reload.theme
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
