# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::LayoutTest < ActionDispatch::IntegrationTest
  fixtures :users, :user_statuses

  def default_headers
    { "Host" => ENV["ID_SERVICE_URL"] || "id.app.localhost" }
  end

  def login_headers(user)
    default_headers.merge("X-TEST-CURRENT-USER" => user.id.to_s)
  end

  test "layout links when not logged in" do
    get new_sign_app_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success

    assert_select "nav" do
      assert_select "a[href*=?]", new_sign_app_up_path, text: I18n.t("sign.app.layout.nav.sign_up")
      assert_select "a[href*=?]", new_sign_app_in_path, text: I18n.t("sign.app.layout.nav.log_in")
      assert_select "a[href*=?]", "/setting", count: 0
      assert_select "a[href*=?][data-turbo-method='delete']", "/authentication", count: 0
    end
  end

  # test "layout links when logged in" do
  #   user = users(:one)
  #   get new_sign_app_up_telephone_url, headers: login_headers(user)

  #   assert_response :success

  #   assert_select "nav" do
  #     assert_select "a[href=?]", new_sign_app_up_path
  #     assert_select "a[href=?]", new_sign_app_in_path
  #     assert_select "a[href*=?]", "/setting", count: 0
  #     assert_select "a[href*=?][data-turbo-method='delete']", "/authentication", count: 0
  #   end
  # end
end
