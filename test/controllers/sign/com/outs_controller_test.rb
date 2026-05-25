# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::OutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "com-out-#{SecureRandom.hex(4)}@example.com")
  end

  test "should get edit raises error without session" do
    get edit_sign_com_out_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :redirect

    assert_equal new_sign_com_in_url(ri: "jp", host: @host), redirect_without_rt(response.location)
    assert_equal edit_sign_com_out_path(ri: "jp"), verified_redirect_return_to(response.location, "com")
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

  test "uses shared logout concern" do
    assert_includes Sign::Com::OutsController.included_modules, Authentication::Logoutable
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

    assert_response :success
    assert_empty flash.to_hash
    assert_predicate token.reload, :revoked?

    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")
  end

  test "signed out page requires a fresh logout notice" do
    get sign_com_out_url(ri: "jp"), headers: { "Host" => @host }

    assert_redirected_to edit_sign_com_out_path(ri: "jp")
  end

  test "destroy without session redirects to sign in" do
    delete sign_com_out_url(ri: "jp"), headers: { "Host" => @host }

    assert_equal new_sign_com_in_url(ri: "jp", host: @host), redirect_without_rt(response.location)
    assert_equal sign_com_out_path(ri: "jp"), verified_redirect_return_to(response.location, "com")
  end

  test "stale tab cannot complete logout after another tab already cleared cookies" do
    token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    get edit_sign_com_out_url(ri: "jp"),
        headers: { "Host" => @host,
                   "X-TEST-CURRENT-RESOURCE" => @visitor.id,
                   "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_response :success

    post sign_com_out_url(ri: "jp"),
         headers: { "Host" => @host,
                    "X-TEST-CURRENT-RESOURCE" => @visitor.id,
                    "X-TEST-SESSION-PUBLIC-ID" => token.public_id, },
         params: { confirm: "1" }

    assert_response :success
    assert_predicate token.reload, :revoked?

    post sign_com_out_url(ri: "jp"), headers: { "Host" => @host }, params: { confirm: "1" }

    assert_equal new_sign_com_in_url(ri: "jp", host: @host), redirect_without_rt(response.location)
    assert_equal sign_com_out_path(ri: "jp"), verified_redirect_return_to(response.location, "com")
  end

  test "destroy resets rails session id to prevent session fixation" do
    token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!

    get edit_sign_com_out_url(ri: "jp"),
        headers: { "Host" => @host,
                   "X-TEST-CURRENT-RESOURCE" => @visitor.id,
                   "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }
    session[:sign_out_fixation_probe] = "attacker-controlled"
    old_session_id = session.id

    delete sign_com_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-RESOURCE" => @visitor.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_response :success
    assert_not_nil old_session_id
    assert_not_nil session.id
    assert_not_equal old_session_id, session.id
    assert_nil session[:sign_out_fixation_probe]
    assert_predicate token.reload, :revoked?
  end

  test "ordinary destroy does not issue a signed out notice" do
    token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    delete sign_com_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-RESOURCE" => @visitor.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_response :success
    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")

    get sign_com_out_url(ri: "jp"), headers: { "Host" => @host }

    assert_redirected_to edit_sign_com_out_path(ri: "jp")
  end

  test "destroy redirects to safe rt after logout" do
    get edit_sign_com_out_url(ri: "jp"), headers: { "Host" => @host }
    token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain
    rt = signed_return_target(sign_com_configuration_path(ri: "jp"), surface: "com")

    delete sign_com_out_url(ri: "jp", rt: rt),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-RESOURCE" => @visitor.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_redirected_to sign_com_configuration_path(ri: "jp")
    assert_predicate token.reload, :revoked?
  end

  test "destroy with unsafe rt fails closed after logout" do
    token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain
    rt = "not-a-valid-return-target-token"

    delete sign_com_out_url(ri: "jp", rt: rt),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-RESOURCE" => @visitor.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_response :unprocessable_content
    assert_predicate token.reload, :revoked?
  end

  test "destroy rejects legacy base64 rt after logout" do
    token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain
    legacy_rt = Base64.urlsafe_encode64(sign_com_configuration_path(ri: "jp"))

    delete sign_com_out_url(ri: "jp", rt: legacy_rt),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-RESOURCE" => @visitor.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_response :unprocessable_content
    assert_predicate token.reload, :revoked?
  end

  # Regression: ordinary logout must revoke ONLY the current session's
  # token. Sign-out on one browser must not sign the visitor out on every
  # other device.
  test "destroy revokes only the current session token and leaves other devices signed in" do
    current_token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    other_token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    refresh_plain = current_token.rotate_refresh_token!
    other_token.rotate_refresh_token!

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    delete sign_com_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-RESOURCE" => @visitor.id,
                      "X-TEST-SESSION-PUBLIC-ID" => current_token.public_id, }

    assert_response :success
    assert_predicate current_token.reload, :revoked?,
                     "current session token must be revoked"
    assert_not other_token.reload.revoked?,
               "another device's token must remain active after a single-browser logout"
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

    assert_response :success

    assert_empty cookies[Authentication::Base::ACCESS_COOKIE_KEY].to_s
    assert_empty cookies[Authentication::Base::REFRESH_COOKIE_KEY].to_s
    assert_empty cookies[Authentication::Base::DBSC_COOKIE_KEY].to_s
  end

  private

  def signed_return_target(return_to, surface:)
    return_target_token_harness.issue(
      return_to: return_to,
      flow: "authentication",
      surface: surface,
      session_nonce: session.fetch(:authentication_return_target_nonce),
    )
  end

  def verified_redirect_return_to(location, surface)
    return_target_token_harness.verified_return_to(
      rt_from_location(location),
      expected_flow: "authentication",
      expected_surface: surface,
      session_nonce: session[:authentication_return_target_nonce],
    )
  end

  def return_target_token_harness
    @return_target_token_harness ||= Class.new do
      include ReturnTargets::SignedTokenSupport

      def issue(return_to:, flow:, surface:, session_nonce:, expires_in: 15.minutes)
        path = signed_target_internal_path(return_to)
        claims = signed_target_claims(flow: flow, surface: surface, session_nonce: session_nonce)
        issue_signed_target_token(
          payload: claims.merge("return_to" => path),
          purpose: :return_target,
          salt: "return_target_token",
          expires_in: expires_in,
        )
      end

      def verified_return_to(token, expected_flow:, expected_surface:, session_nonce:)
        payload = verified_signed_target_payload(
          token,
          purpose: :return_target,
          salt: "return_target_token",
          expected_flow: expected_flow,
          expected_surface: expected_surface,
          session_nonce: session_nonce,
        )
        signed_target_internal_path(payload&.fetch("return_to", nil))
      end
    end.new
  end

  def redirect_without_rt(location)
    uri = URI.parse(location)
    query = Rack::Utils.parse_nested_query(uri.query).except("rt")
    uri.query = query.presence&.to_query
    uri.to_s
  end

  def rt_from_location(location)
    Rack::Utils.parse_nested_query(URI.parse(location).query).fetch("rt")
  end
end
