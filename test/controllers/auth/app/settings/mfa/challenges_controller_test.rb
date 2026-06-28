# typed: false
# frozen_string_literal: true

require "test_helper"

# Auth::App::Settings::Mfa::ChallengesController is a redirect shim to base/app/identity/mfa/challenge.
class Auth::App::Settings::Mfa::ChallengesControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_statuses, :client_token_kinds

  setup do
    host! ENV.fetch("AUTH_SERVICE_URL", "auth.app.localhost")
    @user = clients(:one)
    @user.update_columns(purged_at: Retainable::SENTINEL) if @user.purged_at.blank?
    @headers = as_user_headers(@user, host: host)
    @token = ClientToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
    satisfy_user_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_mfa")
  end

  test "show redirects to base identity mfa challenge" do
    get auth_app_settings_mfa_challenge_url(ri: "jp"), headers: @headers

    assert_response :see_other
    assert_redirected_to base_app_identity_mfa_challenge_path(ri: "jp")
  end

  test "update route is not exposed" do
    patch auth_app_settings_mfa_challenge_url(ri: "jp"),
          params: { user: { mfa_level_id: ClientMfaLevel::FULL.to_s } },
          headers: @headers

    assert_response :not_found
  end
end
