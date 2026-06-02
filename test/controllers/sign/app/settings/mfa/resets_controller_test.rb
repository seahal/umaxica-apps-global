# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Settings::Mfa::ResetsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_statuses, :client_token_kinds

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    host! @host
    @user = clients(:one)
    @headers = as_user_headers(@user, host: @host)
  end

  test "routes to the MFA reset request endpoint" do
    assert_equal "/mfa/reset", URI.parse(sign_app_mfa_reset_url(ri: "jp")).path
  end

  test "show requires an authenticated client" do
    get sign_app_mfa_reset_url(ri: "jp")

    assert_response :redirect
  end

  test "show is reachable for an authenticated client" do
    get sign_app_mfa_reset_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_equal "sign/app/settings/mfa/resets", @controller.controller_path
    assert_select "h1", I18n.t("sign.app.settings.show.mfa_reset")
    assert_select "p", text: I18n.t("sign.app.settings.mfa.show.reset_unavailable")
  end

  test "show is reachable from a restricted MFA session" do
    token = create_restricted_session(@user)

    get sign_app_mfa_reset_url(ri: "jp"),
        headers: as_user_headers_with_token(@user, token, host: @host)

    assert_response :success
    assert_select "p", text: I18n.t("sign.app.settings.mfa.show.reset_unavailable")
  end

  test "create is routed for future reset request submission" do
    post sign_app_mfa_reset_url(ri: "jp"), headers: @headers

    assert_redirected_to sign_app_mfa_reset_url(ri: "jp")
    assert_equal I18n.t("sign.app.settings.mfa.show.reset_unavailable"), flash[:alert]
  end

  private

  def create_restricted_session(user)
    token = ClientToken.new(
      user: user,
      user_token_status_id: ClientTokenStatus::RESTRICTED,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discarded_at: 1.month.from_now,
    )
    token.save!(validate: false)
    token.rotate_refresh_token!
    token
  end

  def as_user_headers_with_token(user, token, host:)
    access_token = Authentication::Base::Token.encode(user, host: host, session_public_id: token.public_id)
    {
      "Host" => host,
      "Authorization" => "Bearer #{access_token}",
      "Cookie" => "#{Authentication::Base::ACCESS_COOKIE_KEY}=#{access_token}",
    }
  end
end
