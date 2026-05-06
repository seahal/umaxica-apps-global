# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Configuration::OutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :user_statuses

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = users(:one)
    @host = ENV["ID_SERVICE_URL"] || "id.app.localhost"
  end

  test "should get edit raises error without session" do
    get edit_sign_app_configuration_out_url(ri: "jp"), headers: { "Host" => @host }

    rt = Base64.urlsafe_encode64(edit_sign_app_configuration_out_url(ri: "jp", host: @host))

    assert_redirected_to new_sign_app_in_url(rt: rt, host: @host)
  end

  test "should show up link on edit page" do
    get edit_sign_app_configuration_out_url(ri: "jp"),
        headers: { "Host" => @host, "X-TEST-CURRENT-USER" => @user.id }

    assert_response :success
    assert_select "a[href=?]", sign_app_configuration_path(ri: "jp")
  end

  test "should destroy raises error without session" do
    delete sign_app_configuration_out_url(ri: "jp"), headers: { "Host" => @host }

    rt = Base64.urlsafe_encode64(sign_app_configuration_out_url(ri: "jp", host: @host))

    assert_redirected_to new_sign_app_in_url(rt: rt, host: @host)
  end

  test "should destroy with user session even without step-up verification" do
    token = UserToken.create!(user: @user)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    delete sign_app_configuration_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-USER" => @user.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_redirected_to sign_app_root_path(ri: "jp")
    assert_equal I18n.t("sign.shared.sign_out.success"), flash[:notice]
    assert_not UserToken.exists?(id: token.id)
  end

  test "logout clears all auth cookies" do
    token = UserToken.create!(user: @user)
    refresh_plain = token.rotate_refresh_token!

    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = "test_access_token"
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain
    cookies[Authentication::Base::DBSC_COOKIE_KEY] = "test_dbsc_value"

    delete sign_app_configuration_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-USER" => @user.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_redirected_to sign_app_root_path(ri: "jp")

    # All auth cookies must be cleared after logout
    assert_empty cookies[Authentication::Base::ACCESS_COOKIE_KEY].to_s
    assert_empty cookies[Authentication::Base::REFRESH_COOKIE_KEY].to_s
    assert_empty cookies[Authentication::Base::DBSC_COOKIE_KEY].to_s
  end
end
