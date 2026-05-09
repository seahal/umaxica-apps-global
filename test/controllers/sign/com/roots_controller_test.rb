# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::RootsControllerTest < ActionDispatch::IntegrationTest
  include RootThemeCookieHelper

  test "GET / renders root page" do
    get sign_com_root_url(ri: "jp")

    assert_response :success
    assert_select "a[href*=?]", new_sign_com_up_path
    assert_select "a[href*=?]", new_sign_com_in_path
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
                    text: I18n.t("sign.app.preferences.footer.home")
      assert_select "a[href=?]", sign_com_preference_url(ri: "jp"),
                    text: I18n.t("sign.app.preferences.footer.preference")
      assert_select "a[href=?]", sign_com_configuration_url(ri: "jp"),
                    text: I18n.t("sign.app.preferences.footer.configuration")
    end
  end

  test "does not create preference records on root" do
    assert_no_difference("ComPreference.count") do
      get sign_com_root_url(ri: "jp")
    end

    assert_response :success
  end

  test "sets theme cookie" do
    assert_theme_cookie_for(
      host: "id.com.localhost",
      path: :sign_com_root_path,
      label: "sign com root",
      ri: "jp",
    )
  end
end
