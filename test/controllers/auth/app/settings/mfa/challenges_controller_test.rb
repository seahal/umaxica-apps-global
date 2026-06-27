# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Settings::Mfa::ChallengesControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_statuses, :client_token_kinds

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = clients(:one)
    @user.update_columns(purged_at: Retainable::SENTINEL) if @user.purged_at.blank?
    @headers = as_user_headers(@user, host: host)
    @token = ClientToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
    satisfy_user_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_mfa")
  end

  test "should get show" do
    get auth_app_settings_mfa_challenge_url(ri: "jp"), headers: authenticated_headers

    assert_response :success
    assert_select "h1", I18n.t("sign.app.settings.mfa.show.title")
    assert_select "p", text: I18n.t("sign.app.settings.mfa.show.reset_unavailable")
    assert_equal "/settings/mfa/challenge", URI.parse(auth_app_settings_mfa_challenge_url(ri: "jp")).path
  end

  test "show redirects to verification when step-up is not satisfied" do
    cookies.delete(ClientVerification.cookie_name)
    @token.update!(created_at: 1.hour.ago, last_step_up_at: nil, last_step_up_scope: nil)

    get auth_app_settings_mfa_challenge_url(ri: "jp"), headers: authenticated_headers

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification", uri.path
    assert_equal "settings_mfa", query["scope"]
    assert_equal "jp", query["ri"]
    assert_predicate query["pt"], :present?
  end

  test "update route is not exposed" do
    @user.update!(mfa_level_id: ClientMfaLevel::NOTHING, mfa_level_enabled: false)

    patch auth_app_settings_mfa_challenge_url(ri: "jp"),
          params: { user: { mfa_level_id: ClientMfaLevel::FULL.to_s } },
          headers: authenticated_headers

    assert_response :not_found
    assert_equal ClientMfaLevel::NOTHING, @user.reload.mfa_level_id
    assert_not_predicate @user, :mfa_level_enabled?
  end

  private

  def authenticated_headers = @headers
end
