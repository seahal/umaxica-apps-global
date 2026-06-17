# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/root_theme_cookie_helper"

class Sign::Org::RootsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  include RootThemeCookieHelper

  test "GET / renders root page" do
    get sign_org_root_url(ri: "jp")

    assert_response :success
    assert_select "a[href*=?]", sign_org_sign_up_path
    assert_select "a[href*=?]", sign_org_sign_in_path
  end

  test "renders layout contract" do
    get sign_org_root_url(ri: "jp")

    assert_response :success
    assert_layout_contract
  end

  test "footer contains navigation links" do
    get sign_org_root_url(ri: "jp")

    assert_response :success
    assert_select "footer" do
      assert_select "a"
      assert_select "a[href=?]", sign_org_root_url(ri: "jp"),
                    text: I18n.t("sign.org.preferences.footer.home")
      assert_select "a[href=?]",
                    acme_org_preference_url(
                      ri: "jp",
                      host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"),
                    ),
                    text: I18n.t("sign.org.preferences.footer.preference")
      assert_select "a[href=?]", sign_org_settings_url(ri: "jp"),
                    text: I18n.t("sign.org.preferences.footer.settings")
    end
  end

  test "creates preference cookies on root" do
    assert_difference("OrgPreference.count", 1) do
      get sign_org_root_url(ri: "jp")
    end

    assert_response :success
    assert_predicate cookies[PreferenceCookieName.access(surface: :org)], :present?
    assert_predicate cookies[PreferenceCookieName.refresh(surface: :org)], :present?
  end

  test "sets theme cookie" do
    assert_theme_cookie_for(
      host: ENV.fetch("SIGN_STAFF_URL", "id.umaxica.org"),
      path: :sign_org_root_path,
      label: "sign org root",
      ri: "jp",
    )
  end

  test "GET / renders root when logged in" do
    staff = operators(:one)

    get sign_org_root_url(ri: "jp"),
        headers: as_staff_headers(staff, host: ENV.fetch("SIGN_STAFF_URL", "id.umaxica.org"))

    assert_response :success
    assert_select "h1", minimum: 1
  end
end
