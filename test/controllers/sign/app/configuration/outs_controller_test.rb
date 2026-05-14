# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Configuration::OutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :user_statuses, :user_chronicle_events, :user_chronicle_levels

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = users(:one)
    @host = ENV["ID_SERVICE_URL"] || "id.app.localhost"

    ChronicleRecord.connected_to(role: :writing) do
      UserChronicle.delete_all
    end
  end

  test "should get edit raises error without session" do
    get edit_sign_app_out_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :redirect

    rt = Base64.urlsafe_encode64(edit_sign_app_out_url(ri: "jp", host: @host))

    assert_redirected_to new_sign_app_in_url(rt: rt, host: @host)
  end

  test "should show up link on edit page" do
    get edit_sign_app_out_url(ri: "jp"),
        headers: { "Host" => @host, "X-TEST-CURRENT-USER" => @user.id }

    assert_response :success
    assert_select "a[href=?]", sign_app_configuration_path(ri: "jp")
  end

  test "edit page renders a direct logout form" do
    get edit_sign_app_out_url(ri: "jp"),
        headers: { "Host" => @host, "X-TEST-CURRENT-USER" => @user.id }

    assert_response :success
    assert_select "form[action=?][method=?][data-turbo=?]", sign_app_out_path(ri: "jp"), "post", "false" do
      assert_select "input[name=?][value=?]", "_method", "delete", count: 0
      assert_select "input[type=?][name=?][value=?]", "hidden", "confirm", "1", count: 1
      assert_select "button[type=?]", "submit", text: /#{Regexp.escape(I18n.t("sign.shared.sign_out.button"))}/
    end
  end

  test "create without confirmation redirects back to logout confirmation" do
    post sign_app_out_url(ri: "jp"),
         headers: { "Host" => @host, "X-TEST-CURRENT-USER" => @user.id },
         params: { confirm: "0" }

    assert_redirected_to edit_sign_app_out_path(ri: "jp")
    assert_equal I18n.t("views.sign.app.configuration.outs.edit.confirm_label"), flash[:alert]
  end

  test "create logs out with confirmed user session" do
    token = UserToken.create!(user: @user)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post sign_app_out_url(ri: "jp"),
         headers: { "Host" => @host,
                    "X-TEST-CURRENT-USER" => @user.id,
                    "X-TEST-SESSION-PUBLIC-ID" => token.public_id, },
         params: { confirm: "1" }

    assert_redirected_to sign_app_root_path(ri: "jp")
    assert_equal I18n.t("sign.shared.sign_out.success"), flash[:notice]
    assert_not UserToken.exists?(id: token.id)
  end

  test "should destroy raises error without session" do
    delete sign_app_out_url(ri: "jp"), headers: { "Host" => @host }

    rt = Base64.urlsafe_encode64(sign_app_out_url(ri: "jp", host: @host))

    assert_redirected_to new_sign_app_in_url(rt: rt, host: @host)
  end

  test "should destroy with user session even without step-up verification" do
    token = UserToken.create!(user: @user)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    delete sign_app_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-USER" => @user.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_redirected_to sign_app_root_path(ri: "jp")
    assert_equal I18n.t("sign.shared.sign_out.success"), flash[:notice]
    assert_not UserToken.exists?(id: token.id)
  end

  test "destroy records logout activity" do
    token = UserToken.create!(user: @user)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    assert_difference -> { UserChronicle.where(event_id: UserChronicleEvent::LOGGED_OUT).count }, 1 do
      delete sign_app_out_url(ri: "jp"),
             headers: { "Host" => @host,
                        "X-TEST-CURRENT-USER" => @user.id,
                        "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }
    end

    audit = UserChronicle.find_by!(
      event_id: UserChronicleEvent::LOGGED_OUT,
      subject_id: @user.id,
      subject_type: "User",
    )

    assert_equal @user.id, audit.actor_id
    assert_equal "User", audit.actor_type
  end

  test "logout clears all auth cookies" do
    token = UserToken.create!(user: @user)
    refresh_plain = token.rotate_refresh_token!

    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = "test_access_token"
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain
    cookies[Authentication::Base::DBSC_COOKIE_KEY] = "test_dbsc_value"

    delete sign_app_out_url(ri: "jp"),
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
