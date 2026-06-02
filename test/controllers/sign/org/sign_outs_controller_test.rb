# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::SignOutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
    @host = ENV["ID_STAFF_URL"] || "id.org.localhost"
    load_jump_rt_env!
  end

  test "should get edit raises error without session" do
    get edit_sign_org_sign_out_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :redirect

    assert_equal new_sign_org_sign_in_url(ri: "jp", host: @host, protocol: "https"),
                 redirect_without_rt(response.location)
  end

  test "edit page renders a direct logout form" do
    get edit_sign_org_sign_out_url(ri: "jp"),
        headers: { "Host" => @host, "X-TEST-CURRENT-STAFF" => @staff.id }

    assert_response :success
    assert_select "form[action=?][method=?][data-turbo=?]", sign_org_sign_out_path(ri: "jp"), "post", "false" do
      assert_select "input[name=?][value=?]", "_method", "delete", count: 0
      assert_select "input[type=?][name=?][value=?]", "hidden", "confirm", "1", count: 1
      assert_select "button[type=?]", "submit", text: /#{Regexp.escape(I18n.t("sign.shared.sign_out.button"))}/
    end
  end

  test "uses shared logout concern" do
    assert_includes Sign::Org::SignOutsController.included_modules, Authentication::Logoutable
  end

  test "create without confirmation redirects back to logout confirmation" do
    post sign_org_sign_out_url(ri: "jp"),
         headers: { "Host" => @host, "X-TEST-CURRENT-STAFF" => @staff.id },
         params: { confirm: "0" }

    assert_redirected_to edit_sign_org_sign_out_path(ri: "jp")
    assert_equal I18n.t("views.sign.app.settings.outs.edit.confirm_label"), flash[:alert]
  end

  test "create logs out with confirmed staff session" do
    token = OperatorToken.create!(staff: @staff)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain
    access_expires_at = issue_access_cookie!(resource: @staff, token: token)

    post sign_org_sign_out_url(ri: "jp"),
         headers: { "Host" => @host,
                    "X-TEST-CURRENT-STAFF" => @staff.id,
                    "X-TEST-SESSION-PUBLIC-ID" => token.public_id, },
         params: { confirm: "1" }

    assert_response :success
    assert_empty flash.to_hash
    assert_predicate token.reload, :revoked?

    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")
    assert_includes response.body, I18n.t(
      "sign.shared.sign_out.completed_description",
      expires_at: I18n.l(access_expires_at.in_time_zone("Asia/Tokyo"), format: :short),
    )
  end

  test "signed out page requires a fresh logout notice" do
    get sign_org_sign_out_url(ri: "jp"), headers: { "Host" => @host }

    assert_redirected_to edit_sign_org_sign_out_path(ri: "jp")
  end

  test "destroy without session redirects to sign in" do
    delete sign_org_sign_out_url(ri: "jp"), headers: { "Host" => @host }

    assert_equal new_sign_org_sign_in_url(ri: "jp", host: @host, protocol: "https"),
                 redirect_without_rt(response.location)
  end

  test "stale tab cannot complete logout after another tab already cleared cookies" do
    token = OperatorToken.create!(staff: @staff)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    get edit_sign_org_sign_out_url(ri: "jp"),
        headers: { "Host" => @host,
                   "X-TEST-CURRENT-STAFF" => @staff.id,
                   "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_response :success

    post sign_org_sign_out_url(ri: "jp"),
         headers: { "Host" => @host,
                    "X-TEST-CURRENT-STAFF" => @staff.id,
                    "X-TEST-SESSION-PUBLIC-ID" => token.public_id, },
         params: { confirm: "1" }

    assert_response :success
    assert_predicate token.reload, :revoked?

    post sign_org_sign_out_url(ri: "jp"), headers: { "Host" => @host }, params: { confirm: "1" }

    assert_equal new_sign_org_sign_in_url(ri: "jp", host: @host, protocol: "https"),
                 redirect_without_rt(response.location)
  end

  test "should destroy with staff session even without step-up verification" do
    token = OperatorToken.create!(staff: @staff)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    delete sign_org_sign_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-STAFF" => @staff.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_response :success
    assert_predicate token.reload, :revoked?
    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")
  end

  test "ordinary destroy does not issue a signed out notice" do
    token = OperatorToken.create!(staff: @staff)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    delete sign_org_sign_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-STAFF" => @staff.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_response :success
    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")

    get sign_org_sign_out_url(ri: "jp"), headers: { "Host" => @host }

    assert_redirected_to edit_sign_org_sign_out_path(ri: "jp")
  end

  test "destroy rejects pt after logout" do
    token = OperatorToken.create!(staff: @staff)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain
    get edit_sign_org_sign_out_url(ri: "jp"),
        headers: { "Host" => @host,
                   "X-TEST-CURRENT-STAFF" => @staff.id,
                   "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }
    session[:authentication_return_target_nonce] = SecureRandom.urlsafe_base64(16)
    pt = signed_return_target(sign_org_settings_path(ri: "jp"), surface: "org")

    delete sign_org_sign_out_url(ri: "jp", pt: pt),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-STAFF" => @staff.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_response :unprocessable_content
    assert_predicate token.reload, :revoked?
  end

  test "destroy with unsafe pt fails closed after logout" do
    token = OperatorToken.create!(staff: @staff)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain
    pt = "not-a-valid-return-target-token"

    delete sign_org_sign_out_url(ri: "jp", pt: pt),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-STAFF" => @staff.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_response :unprocessable_content
    assert_predicate token.reload, :revoked?
  end

  test "destroy rejects legacy base64 pt after logout" do
    token = OperatorToken.create!(staff: @staff)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain
    legacy_pt = Base64.urlsafe_encode64(sign_org_settings_path(ri: "jp"))

    delete sign_org_sign_out_url(ri: "jp", pt: legacy_pt),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-STAFF" => @staff.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_response :unprocessable_content
    assert_predicate token.reload, :revoked?
  end

  test "destroy resets rails session id to prevent session fixation" do
    token = OperatorToken.create!(staff: @staff)
    token.rotate_refresh_token!

    get edit_sign_org_sign_out_url(ri: "jp"),
        headers: { "Host" => @host,
                   "X-TEST-CURRENT-STAFF" => @staff.id,
                   "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }
    session[:sign_out_fixation_probe] = "attacker-controlled"
    old_session_id = session.id

    delete sign_org_sign_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-STAFF" => @staff.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_response :success
    assert_not_nil old_session_id
    assert_not_nil session.id
    assert_not_equal old_session_id, session.id
    assert_nil session[:sign_out_fixation_probe]
    assert_predicate token.reload, :revoked?
  end

  # Regression: ordinary logout must revoke ONLY the current session's
  # token. OperatorToken normally enforces MAX_SESSIONS_PER_STAFF = 1, so
  # the multi-device shape is hypothetical here — but if invariants ever
  # drift (lifecycle migration, manual DB fix, future relaxation of the
  # limit), the contract is still: a single-browser logout must not cascade.
  test "destroy revokes only the current session token and leaves other devices signed in" do
    current_token = OperatorToken.create!(staff: @staff)
    other_token = OperatorToken.new(staff: @staff)
    other_token.save!(validate: false) # bypass MAX_SESSIONS_PER_STAFF validation
    refresh_plain = current_token.rotate_refresh_token!
    other_token.rotate_refresh_token!

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    delete sign_org_sign_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-STAFF" => @staff.id,
                      "X-TEST-SESSION-PUBLIC-ID" => current_token.public_id, }

    assert_response :success
    assert_predicate current_token.reload, :revoked?,
                     "current session token must be revoked"
    assert_not other_token.reload.revoked?,
               "another device's token must remain active after a single-browser logout"
  end

  test "destroy rejects current session token belonging to another operator" do
    other_staff = operators(:two)
    other_token = OperatorToken.create!(staff: other_staff)
    other_token.rotate_refresh_token!

    delete sign_org_sign_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-STAFF" => @staff.id,
                      "X-TEST-SESSION-PUBLIC-ID" => other_token.public_id, }

    assert_response :forbidden
    assert_predicate other_token.reload, :currently_usable?
  end

  test "logout clears all auth cookies" do
    token = OperatorToken.create!(staff: @staff)
    refresh_plain = token.rotate_refresh_token!

    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = "test_access_token"
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain
    cookies[Authentication::Base::DBSC_COOKIE_KEY] = "test_dbsc_value"

    delete sign_org_sign_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-STAFF" => @staff.id,
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
    location = jump_rt_url_from_location(location) if URI.parse(location).host == "jump.umaxica.net"
    uri = URI.parse(location)
    query = Rack::Utils.parse_nested_query(uri.query).except("pt")
    uri.query = query.presence&.to_query
    uri.to_s
  end

  def rt_from_location(location)
    location = jump_rt_url_from_location(location) if URI.parse(location).host == "jump.umaxica.net"
    Rack::Utils.parse_nested_query(URI.parse(location).query).fetch("pt")
  end

  def issue_access_cookie!(resource:, token:)
    access_expires_at = 10.minutes.from_now.change(usec: 0)
    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = Authentication::Base::Token.encode(
      resource,
      host: @host,
      session_public_id: token.public_id,
      oidc_sid: token.public_id,
      resource_type: "operator",
      expires_at: access_expires_at,
      acr: "aal1",
      jwt_issuer_id: "surface:SIGN_ORG",
    )
    access_expires_at
  end
end
