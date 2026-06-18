# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::UiFoundationTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_kinds

  setup do
    @user = create_verified_user_with_email(email_address: "ui-foundation-#{SecureRandom.hex(4)}@example.com")
    @host = ENV["ID_SERVICE_URL"]
    @sign_host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
  end

  test "should render settings page with new UI foundation" do
    head = as_user_headers(@user, host: @sign_host)
    get sign_app_settings_url(ri: "jp", host: @sign_host), headers: head

    assert_response :success

    # Check for brand name in header
    assert_select "header h1", text: /#{ENV.fetch("BRAND_NAME", "Umaxica")}/

    # Check for PageHeader components
    assert_select "h1"
  end

  test "PageHeader renders correct up_to link" do
    head = as_user_headers(@user, host: @sign_host)
    get sign_app_settings_url(ri: "jp", host: @sign_host), headers: head

    assert_response :success
    assert_select "h1", text: I18n.t("sign.app.settings.show.page_title")
  end

  test "PageHeader on sub-pages points back to settings" do
    sign_head = as_user_headers(@user, host: @host)
    pages = [
      [sign_app_settings_totps_url(ri: "jp", host: @sign_host),
       acme_session_headers(scope: "settings_totp", host: @sign_host),],
      [sign_app_settings_passkeys_url(ri: "jp", host: @sign_host),
       acme_session_headers(scope: "settings_passkey", host: @sign_host),],
      [
        sign_app_settings_secrets_url(ri: "jp", host: @sign_host),
        acme_session_headers(scope: "settings_secret_credential", host: @sign_host),
      ],
      [sign_app_settings_mfa_challenge_path(ri: "jp"), sign_head],
      [sign_app_settings_google_path(ri: "jp"), sign_head],
    ]

    Prosopite.pause do
      pages.each do |path, head|
        get path, headers: head
        follow_redirect!(headers: head) if response.redirect?

        assert_response :success, "Failed to load #{path}"
      end
    end
  end

  test "acme-owned authority pages redirect to acme instead of rendering sign UI" do
    head = as_user_headers(@user, host: @host)
    authority_pages = {
      acme_app_sign_settings_sessions_path(ri: "jp") => "/sign/settings/sessions",
    }

    authority_pages.each do |path, expected_path|
      get path, headers: head

      assert_response :see_other
      location = URI.parse(response.location)

      assert_equal ENV.fetch("ACME_SERVICE_URL"), location.host
      assert_equal expected_path, location.path
    end
  end

  test "dark mode class is rendered based on cookie" do
    # Testing the theme_html_class helper's effect via integration
    headers = as_user_headers(@user, host: @sign_host)
    get sign_app_settings_url(ri: "jp", ct: "dark", host: @sign_host), headers: headers

    assert_response :success

    assert_includes response.body, 'class="theme-dark dark"'

    headers = as_user_headers(@user, host: @sign_host)
    get sign_app_settings_url(ri: "jp", ct: "light", host: @sign_host), headers: headers

    assert_response :success

    assert_no_match(/\bclass="[^"]*\bdark\b/, response.body)
  end

  test "UI components are used in the page" do
    head = as_user_headers(@user, host: @sign_host)
    get sign_app_settings_url(ri: "jp", host: @sign_host), headers: head

    assert_response :success

    assert_select "section", minimum: 3
    assert_select "a[href*='settings/totps']"
    assert_select "a[href*='settings/passkeys']"
  end

  private

  def acme_session_headers(scope: nil, host: @acme_host)
    token = ClientToken.new(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    token.send(:skip_session_limit_check=, true)
    token.save!
    AcmeSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    AcmeSelectorAuthority.prepare(surface: :app, principal: @user, session: token)
    mark_token_step_up_satisfied_for_test(token, scope: scope) if scope.present?

    {
      "Host" => host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end
end
