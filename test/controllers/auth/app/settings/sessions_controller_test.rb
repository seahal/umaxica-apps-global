# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Auth::App::Settings::SessionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_statuses, :client_token_kinds

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @acme_host = ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")
    @user = clients(:one)
    @current_token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
  end

  test "index redirects to acme identity session inventory" do
    get auth_app_settings_sessions_url(ri: "jp"), headers: session_headers

    assert_redirected_to base_app_identity_sessions_path(ri: "jp")
  end

  test "session revocation routes require authentication" do
    post auth_app_settings_session_revocation_url("missing-session", ri: "jp"), headers: { "Host" => @host }

    assert_response :gone
    assert_predicate @current_token.reload, :currently_usable?
  end

  test "destroy revokes the selected session" do
    other_token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    post auth_app_settings_session_revocation_url(other_token.public_id, ri: "jp"), headers: session_headers

    assert_response :gone
    assert_predicate other_token.reload, :currently_usable?
  end

  test "others revokes other sessions" do
    other_token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    post auth_app_settings_revocations_others_url(ri: "jp"), headers: session_headers

    assert_response :gone
    assert_predicate @current_token.reload, :currently_usable?
    assert_predicate other_token.reload, :currently_usable?
  end

  test "revoke all revokes every session" do
    other_token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    post auth_app_settings_revocations_all_url(ri: "jp"), headers: session_headers

    assert_response :gone
    assert_predicate @current_token.reload, :currently_usable?
    assert_predicate other_token.reload, :currently_usable?
  end

  private

  def session_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @current_token.public_id,
    }
  end
end
