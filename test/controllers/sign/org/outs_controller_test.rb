# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::OutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_identity_statuses

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
    @host = ENV["ID_STAFF_URL"] || "id.org.localhost"
  end

  test "should get edit raises error without session" do
    get edit_sign_org_out_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :redirect

    rt = Base64.urlsafe_encode64(edit_sign_org_out_url(ri: "jp", host: @host))

    assert_redirected_to new_sign_org_in_url(rt: rt, host: @host)
  end

  test "edit page renders a direct logout form" do
    get edit_sign_org_out_url(ri: "jp"),
        headers: { "Host" => @host, "X-TEST-CURRENT-STAFF" => @staff.id }

    assert_response :success
    assert_select "form[action=?][method=?][data-turbo=?]", sign_org_out_path(ri: "jp"), "post", "false" do
      assert_select "input[name=?][value=?]", "_method", "delete", count: 0
      assert_select "input[type=?][name=?][value=?]", "hidden", "confirm", "1", count: 1
      assert_select "button[type=?]", "submit", text: /#{Regexp.escape(I18n.t("sign.shared.sign_out.button"))}/
    end
  end

  test "uses shared logout concern" do
    assert_includes Sign::Org::OutsController.included_modules, Authentication::Logoutable
  end

  test "create without confirmation redirects back to logout confirmation" do
    post sign_org_out_url(ri: "jp"),
         headers: { "Host" => @host, "X-TEST-CURRENT-STAFF" => @staff.id },
         params: { confirm: "0" }

    assert_redirected_to edit_sign_org_out_path(ri: "jp")
    assert_equal I18n.t("views.sign.app.configuration.outs.edit.confirm_label"), flash[:alert]
  end

  test "create logs out with confirmed staff session" do
    token = OperatorToken.create!(staff: @staff)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post sign_org_out_url(ri: "jp"),
         headers: { "Host" => @host,
                    "X-TEST-CURRENT-STAFF" => @staff.id,
                    "X-TEST-SESSION-PUBLIC-ID" => token.public_id, },
         params: { confirm: "1" }

    assert_response :see_other
    assert_redirected_to sign_org_signed_out_path(ri: "jp")
    assert_predicate token.reload, :revoked?

    follow_redirect!

    assert_response :success
    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")
  end

  test "signed out page requires a fresh logout notice" do
    get sign_org_signed_out_url(ri: "jp"), headers: { "Host" => @host }

    assert_redirected_to sign_org_root_path(ri: "jp")
  end

  test "should destroy raises error without session" do
    delete sign_org_out_url(ri: "jp"), headers: { "Host" => @host }

    rt = Base64.urlsafe_encode64(sign_org_out_url(ri: "jp", host: @host))

    assert_redirected_to new_sign_org_in_url(rt: rt, host: @host)
  end

  test "should destroy with staff session even without step-up verification" do
    token = OperatorToken.create!(staff: @staff)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    delete sign_org_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-STAFF" => @staff.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_response :see_other
    assert_redirected_to sign_org_signed_out_path(ri: "jp")
    assert_predicate token.reload, :revoked?
  end

  test "signed out page is shown only once after destroy" do
    token = OperatorToken.create!(staff: @staff)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    delete sign_org_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-STAFF" => @staff.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    follow_redirect!

    assert_response :success
    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")

    get sign_org_signed_out_url(ri: "jp"), headers: { "Host" => @host }

    assert_redirected_to sign_org_root_path(ri: "jp")
  end

  test "destroy resets rails session id to prevent session fixation" do
    token = OperatorToken.create!(staff: @staff)
    token.rotate_refresh_token!

    get edit_sign_org_out_url(ri: "jp"),
        headers: { "Host" => @host,
                   "X-TEST-CURRENT-STAFF" => @staff.id,
                   "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }
    session[:sign_out_fixation_probe] = "attacker-controlled"
    old_session_id = session.id

    delete sign_org_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-STAFF" => @staff.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_redirected_to sign_org_signed_out_path(ri: "jp")
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

    delete sign_org_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-STAFF" => @staff.id,
                      "X-TEST-SESSION-PUBLIC-ID" => current_token.public_id, }

    assert_response :see_other
    assert_redirected_to sign_org_signed_out_path(ri: "jp")
    assert_predicate current_token.reload, :revoked?,
                     "current session token must be revoked"
    assert_not other_token.reload.revoked?,
               "another device's token must remain active after a single-browser logout"
  end

  test "logout clears all auth cookies" do
    token = OperatorToken.create!(staff: @staff)
    refresh_plain = token.rotate_refresh_token!

    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = "test_access_token"
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain
    cookies[Authentication::Base::DBSC_COOKIE_KEY] = "test_dbsc_value"

    delete sign_org_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-STAFF" => @staff.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_redirected_to sign_org_signed_out_path(ri: "jp")

    # All auth cookies must be cleared after logout
    assert_empty cookies[Authentication::Base::ACCESS_COOKIE_KEY].to_s
    assert_empty cookies[Authentication::Base::REFRESH_COOKIE_KEY].to_s
    assert_empty cookies[Authentication::Base::DBSC_COOKIE_KEY].to_s
  end
end
