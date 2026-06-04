# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/root_theme_cookie_helper"

class Sign::Com::RootsControllerTest < ActionDispatch::IntegrationTest
  include RootThemeCookieHelper

  test "GET / renders root page" do
    get sign_com_root_url(ri: "jp")

    assert_response :success
    assert_select "a[href*=?]", new_sign_com_sign_up_path
    assert_select "a[href*=?]", new_sign_com_sign_in_path
  end

  test "renders layout contract" do
    get sign_com_root_url(ri: "jp")

    assert_response :success
    assert_layout_contract
  end

  test "footer contains navigation links" do
    get sign_com_root_url(ri: "jp")

    assert_response :success
    assert_select "footer" do
      assert_select "a"
      assert_select "a[href=?]", sign_com_root_url(ri: "jp"),
                    text: I18n.t("sign.com.preferences.footer.home")
      assert_select "a[href=?]", sign_com_preference_url(ri: "jp"),
                    text: I18n.t("sign.com.preferences.footer.preference")
      assert_select "a[href=?]", sign_com_settings_url(ri: "jp"),
                    text: I18n.t("sign.com.preferences.footer.settings")
    end
  end

  test "creates preference cookies on root" do
    assert_difference("ComPreference.count", 1) do
      get sign_com_root_url(ri: "jp")
    end

    assert_response :success
    assert_predicate cookies[Preference::CookieName.access(surface: :com)], :present?
    assert_predicate cookies[Preference::CookieName.refresh(surface: :com)], :present?
  end

  test "sets theme cookie" do
    assert_theme_cookie_for(
      host: ENV.fetch("SIGN_CORPORATE_URL", "id.umaxica.com"),
      path: :sign_com_root_path,
      label: "sign com root",
      ri: "jp",
    )
  end

  test "GET / renders root when logged in" do
    visitor = create_verified_visitor_with_email(email_address: "com-root-logged-in@example.com")
    visitor.visitor_telephones.create!(
      number: "+15550002223",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    get sign_com_root_url(ri: "jp"),
        headers: as_visitor_headers(visitor, host: ENV.fetch("SIGN_CORPORATE_URL", "id.umaxica.com"))

    assert_response :success
    assert_select "h1", minimum: 1
  end
end
