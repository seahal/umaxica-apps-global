# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::RootsControllerTest < ActionDispatch::IntegrationTest
  include RootThemeCookieHelper

  test "GET / renders root page" do
    get sign_org_root_url(ri: "jp")

    assert_response :success
    assert_select "a[href*=?]", new_sign_org_up_path
    assert_select "a[href*=?]", new_sign_org_in_path
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
      assert_select "a[href=?]", sign_org_preference_url(ri: "jp"),
                    text: I18n.t("sign.org.preferences.footer.preference")
      assert_select "a[href=?]", sign_org_configuration_url(ri: "jp"),
                    text: I18n.t("sign.org.preferences.footer.configuration")
    end
  end

  test "generates sha3-384 token digest on root" do
    get sign_org_root_url(ri: "jp")

    assert_response :success
    assert_equal 48, OrgPreference.order(:created_at).last.token_digest.bytesize
  end

  test "sets theme cookie" do
    assert_theme_cookie_for(
      host: "id.org.localhost",
      path: :sign_org_root_path,
      label: "sign org root",
      ri: "jp",
    )
  end
end
