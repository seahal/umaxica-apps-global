# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Configuration::OutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "com-out-#{SecureRandom.hex(4)}@example.com")
  end

  test "should get edit raises error without session" do
    get edit_sign_com_out_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :redirect

    rt = Base64.urlsafe_encode64(edit_sign_com_out_url(ri: "jp", host: @host))

    assert_redirected_to new_sign_com_in_url(rt: rt, host: @host)
  end

  test "edit page renders a direct logout form" do
    get edit_sign_com_out_url(ri: "jp"),
        headers: { "Host" => @host, "X-TEST-CURRENT-RESOURCE" => @visitor.id }

    assert_response :success
    assert_select "form[action=?][method=?][data-turbo=?]", sign_com_out_path(ri: "jp"), "post", "false" do
      assert_select "input[name=?][value=?]", "_method", "delete", count: 0
      assert_select "input[type=?][name=?][value=?]", "hidden", "confirm", "1", count: 1
      assert_select "button[type=?]", "submit", text: /#{Regexp.escape(I18n.t("sign.shared.sign_out.button"))}/
    end
  end

  test "create without confirmation redirects back to logout confirmation" do
    post sign_com_out_url(ri: "jp"),
         headers: { "Host" => @host, "X-TEST-CURRENT-RESOURCE" => @visitor.id },
         params: { confirm: "0" }

    assert_redirected_to edit_sign_com_out_path(ri: "jp")
    assert_equal I18n.t("views.sign.app.configuration.outs.edit.confirm_label"), flash[:alert]
  end

  test "create logs out with confirmed visitor session" do
    token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post sign_com_out_url(ri: "jp"),
         headers: { "Host" => @host,
                    "X-TEST-CURRENT-RESOURCE" => @visitor.id,
                    "X-TEST-SESSION-PUBLIC-ID" => token.public_id, },
         params: { confirm: "1" }

    assert_redirected_to sign_com_root_path(ri: "jp")
    assert_not VisitorToken.exists?(id: token.id)
  end

  test "should destroy raises error without session" do
    delete sign_com_out_url(ri: "jp"), headers: { "Host" => @host }

    rt = Base64.urlsafe_encode64(sign_com_out_url(ri: "jp", host: @host))

    assert_redirected_to new_sign_com_in_url(rt: rt, host: @host)
  end

  test "logout clears all auth cookies" do
    token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    refresh_plain = token.rotate_refresh_token!

    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = "test_access_token"
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain
    cookies[Authentication::Base::DBSC_COOKIE_KEY] = "test_dbsc_value"

    delete sign_com_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-RESOURCE" => @visitor.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_redirected_to sign_com_root_path(ri: "jp")

    assert_empty cookies[Authentication::Base::ACCESS_COOKIE_KEY].to_s
    assert_empty cookies[Authentication::Base::REFRESH_COOKIE_KEY].to_s
    assert_empty cookies[Authentication::Base::DBSC_COOKIE_KEY].to_s
  end
end
