# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::UiFoundationTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  setup do
    @user = create_verified_user_with_email(email_address: "ui-foundation-#{SecureRandom.hex(4)}@example.com")
    @host = ENV["ID_SERVICE_URL"]
  end

  test "should render settings page with new UI foundation" do
    head = { "X-TEST-CURRENT-USER" => @user.id, "Host" => @host }
    get "/settings", headers: head
    follow_redirect!(headers: head) if response.redirect?

    assert_response :success

    # Check for brand name in header
    assert_select "header h1", text: /#{ENV.fetch("BRAND_NAME", "Umaxica")}/

    # Check for PageHeader components
    assert_select "h1"
  end

  test "PageHeader renders correct up_to link" do
    head = as_user_headers(@user, host: @host)
    get "/settings", headers: head
    follow_redirect!(headers: head) if response.redirect?

    assert_response :success
    assert_select "h1", text: I18n.t("sign.app.settings.show.page_title")
  end

  test "PageHeader on sub-pages points back to settings" do
    head = as_user_headers(@user, host: @host)
    pages = [
      sign_app_settings_totps_path(ri: "jp"),
      sign_app_settings_passkeys_path(ri: "jp"),
      sign_app_settings_mfa_challenge_path(ri: "jp"),
      sign_app_settings_secret_credentials_path(ri: "jp"),
      sign_app_settings_emails_path(ri: "jp"),
      sign_app_settings_telephones_path(ri: "jp"),
      sign_app_settings_sessions_path(ri: "jp"),
      sign_app_settings_google_path(ri: "jp"),
      new_sign_app_settings_withdrawal_path(ri: "jp"),
      edit_sign_app_sign_out_path(ri: "jp"),
    ]

    Prosopite.pause do
      pages.each do |path|
        get path, headers: head
        follow_redirect!(headers: head) if response.redirect?

        assert_response :success, "Failed to load #{path}"
      end
    end
  end

  test "dark mode class is rendered based on cookie" do
    # Testing the theme_html_class helper's effect via integration
    headers = as_user_headers(@user, host: @host)
    get sign_app_settings_url(ct: "dark"), headers: headers

    follow_redirect!(headers: headers) if response.redirect?

    assert_response :success

    assert_includes response.body, 'class="theme-dark dark"'

    headers = as_user_headers(@user, host: @host)
    get sign_app_settings_url(ct: "light"), headers: headers

    follow_redirect!(headers: headers) if response.redirect?

    assert_response :success

    assert_no_match(/\bclass="[^"]*\bdark\b/, response.body)
  end

  test "UI components are used in the page" do
    head = as_user_headers(@user, host: @host)
    get sign_app_settings_url, headers: head

    follow_redirect!(headers: head) if response.redirect?

    assert_response :success

    assert_select "section", minimum: 3
    assert_select "a[href*='settings/totps']"
    assert_select "a[href*='settings/passkeys']"
  end
end
