# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::OutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_chronicle_events, :client_chronicle_levels

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = clients(:one)
    @host = ENV["ID_SERVICE_URL"] || "id.app.localhost"

    ChronicleRecord.connected_to(role: :writing) do
      ClientChronicle.delete_all
    end
  end

  test "should get edit raises error without session" do
    get edit_sign_app_out_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :redirect

    assert_equal new_sign_app_in_url(ri: "jp", host: @host, protocol: "https"), redirect_without_rt(response.location)
    assert_equal edit_sign_app_out_path(ri: "jp"), verified_redirect_return_to(response.location, "app")
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

  test "uses shared logout concern" do
    assert_includes Sign::App::OutsController.included_modules, Authentication::Logoutable
  end

  test "create without confirmation redirects back to logout confirmation" do
    post sign_app_out_url(ri: "jp"),
         headers: { "Host" => @host, "X-TEST-CURRENT-USER" => @user.id },
         params: { confirm: "0" }

    assert_redirected_to edit_sign_app_out_path(ri: "jp")
    assert_equal I18n.t("views.sign.app.configuration.outs.edit.confirm_label"), flash[:alert]
  end

  test "create logs out with confirmed user session" do
    token = ClientToken.create!(user: @user)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    assert_difference -> { ClientSignOutCycle.where(token: token).count }, 1 do
      post sign_app_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-USER" => @user.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, },
           params: { confirm: "1" }
    end

    assert_response :success
    assert_empty flash.to_hash
    assert_predicate token.reload, :revoked?
    assert_predicate ClientSignOutCycle.recent_first.find_by!(token: token), :sign_out_completed?

    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")
  end

  test "signed out page requires a fresh logout notice" do
    get sign_app_out_url(ri: "jp"), headers: { "Host" => @host }

    assert_redirected_to edit_sign_app_out_path(ri: "jp")
  end

  test "signed out page rejects an expired logout notice" do
    get edit_sign_app_out_url(ri: "jp"), headers: { "Host" => @host }
    session[:sign_out_notice] = {
      "expires_at" => 1.minute.ago.iso8601,
      "remaining_views" => 1,
    }

    get sign_app_out_url(ri: "jp"), headers: { "Host" => @host }

    assert_redirected_to edit_sign_app_out_path(ri: "jp")
  end

  test "destroy without session redirects to sign in" do
    delete sign_app_out_url(ri: "jp"), headers: { "Host" => @host }

    assert_equal new_sign_app_in_url(ri: "jp", host: @host, protocol: "https"), redirect_without_rt(response.location)
    assert_equal sign_app_out_path(ri: "jp"), verified_redirect_return_to(response.location, "app")
  end

  test "stale tab cannot complete logout after another tab already cleared cookies" do
    token = ClientToken.create!(user: @user)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    get edit_sign_app_out_url(ri: "jp"),
        headers: { "Host" => @host,
                   "X-TEST-CURRENT-USER" => @user.id,
                   "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_response :success

    post sign_app_out_url(ri: "jp"),
         headers: { "Host" => @host,
                    "X-TEST-CURRENT-USER" => @user.id,
                    "X-TEST-SESSION-PUBLIC-ID" => token.public_id, },
         params: { confirm: "1" }

    assert_response :success
    assert_predicate token.reload, :revoked?

    assert_no_difference -> { ClientChronicle.where(event_id: ClientChronicleEvent::LOGGED_OUT).count } do
      post sign_app_out_url(ri: "jp"), headers: { "Host" => @host }, params: { confirm: "1" }
    end
    assert_equal new_sign_app_in_url(ri: "jp", host: @host, protocol: "https"), redirect_without_rt(response.location)
    assert_equal sign_app_out_path(ri: "jp"), verified_redirect_return_to(response.location, "app")
  end

  test "should destroy with user session even without step-up verification" do
    token = ClientToken.create!(user: @user)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    delete sign_app_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-USER" => @user.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_response :success
    assert_empty flash.to_hash
    assert_predicate token.reload, :revoked?
    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")
  end

  test "ordinary destroy does not issue a signed out notice" do
    token = ClientToken.create!(user: @user)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    delete sign_app_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-USER" => @user.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_response :success
    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")

    get sign_app_out_url(ri: "jp"), headers: { "Host" => @host }

    assert_redirected_to edit_sign_app_out_path(ri: "jp")
  end

  test "destroy redirects to safe pt after logout" do
    get edit_sign_app_out_url(ri: "jp"), headers: { "Host" => @host }
    token = ClientToken.create!(user: @user)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain
    pt = signed_return_target(sign_app_configuration_path(ri: "jp"), surface: "app")

    delete sign_app_out_url(ri: "jp", pt: pt),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-USER" => @user.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_redirected_to sign_app_configuration_path(ri: "jp")
    assert_predicate token.reload, :revoked?
  end

  test "destroy with unsafe pt fails closed after logout" do
    token = ClientToken.create!(user: @user)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain
    pt = "not-a-valid-return-target-token"

    delete sign_app_out_url(ri: "jp", pt: pt),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-USER" => @user.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_response :unprocessable_content
    assert_predicate token.reload, :revoked?
  end

  test "destroy rejects legacy base64 pt after logout" do
    token = ClientToken.create!(user: @user)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain
    legacy_rt = Base64.urlsafe_encode64(sign_app_configuration_path(ri: "jp"))

    delete sign_app_out_url(ri: "jp", pt: legacy_rt),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-USER" => @user.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_response :unprocessable_content
    assert_predicate token.reload, :revoked?
  end

  test "destroy resets rails session id to prevent session fixation" do
    token = ClientToken.create!(user: @user)
    token.rotate_refresh_token!

    get edit_sign_app_out_url(ri: "jp"),
        headers: { "Host" => @host,
                   "X-TEST-CURRENT-USER" => @user.id,
                   "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }
    session[:sign_out_fixation_probe] = "attacker-controlled"
    old_session_id = session.id

    delete sign_app_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-USER" => @user.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_response :success
    assert_not_nil old_session_id
    assert_not_nil session.id
    assert_not_equal old_session_id, session.id
    assert_nil session[:sign_out_fixation_probe]
    assert_predicate token.reload, :revoked?
  end

  test "destroy records logout activity" do
    token = ClientToken.create!(user: @user)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    assert_difference -> { ClientChronicle.where(event_id: ClientChronicleEvent::LOGGED_OUT).count }, 1 do
      assert_no_difference -> { ClientChronicle.where(event_id: ClientChronicleEvent::LOGOUT).count } do
        delete sign_app_out_url(ri: "jp"),
               headers: { "Host" => @host,
                          "X-TEST-CURRENT-USER" => @user.id,
                          "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }
      end
    end

    audit = ClientChronicle.find_by!(
      event_id: ClientChronicleEvent::LOGGED_OUT,
      subject_id: @user.id,
      subject_type: "Client",
    )

    assert_equal @user.id, audit.actor_id
    assert_equal "Client", audit.actor_type
  end

  # Regression: ordinary logout must revoke ONLY the current session's
  # token. A previous refactor accidentally routed logout through
  # Oidc::SingleLogoutService, which revokes every active token for the
  # user (i.e. every device). Sign-out on one browser must not sign the
  # user out on every other device.
  test "destroy revokes only the current session token and leaves other devices signed in" do
    current_token = ClientToken.create!(user: @user)
    other_token = ClientToken.create!(user: @user)
    refresh_plain = current_token.rotate_refresh_token!
    other_token.rotate_refresh_token!

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    delete sign_app_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-USER" => @user.id,
                      "X-TEST-SESSION-PUBLIC-ID" => current_token.public_id, }

    assert_response :success
    assert_predicate current_token.reload, :revoked?,
                     "current session token must be revoked"
    assert_not other_token.reload.revoked?,
               "another device's token must remain active after a single-browser logout"
  end

  test "logout clears all auth cookies" do
    token = ClientToken.create!(user: @user)
    refresh_plain = token.rotate_refresh_token!

    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = "test_access_token"
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain
    cookies[Authentication::Base::DBSC_COOKIE_KEY] = "test_dbsc_value"

    delete sign_app_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-USER" => @user.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_response :success

    # All auth cookies must be cleared after logout
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
      include ::Redirects::SignedTargetSupport

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
    query = Rack::Utils.parse_nested_query(uri.query).except("pt")
    uri.query = query.presence&.to_query
    uri.to_s
  end

  def rt_from_location(location)
    Rack::Utils.parse_nested_query(URI.parse(location).query).fetch("pt")
  end
end
