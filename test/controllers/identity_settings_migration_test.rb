# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class IdentitySettingsMigrationTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_kinds, :client_token_statuses

  setup do
    @sign_host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL")
    @acme_host = ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
  end

  test "sign settings root redirects to acme identity" do
    get sign_app_settings_url(ri: "jp"), headers: sign_headers

    assert_redirected_to acme_app_identity_url(ri: "jp")
  end

  test "moved sign get routes redirect to acme identity" do
    get auth_app_settings_emails_url(ri: "jp"), headers: sign_headers

    assert_redirected_to acme_app_identity_emails_path(ri: "jp")

    get sign_app_settings_birthdate_url(ri: "jp"), headers: sign_headers

    assert_redirected_to acme_app_identity_birthdate_path(ri: "jp")

    get sign_app_settings_activities_url(ri: "jp"), headers: sign_headers

    assert_redirected_to acme_app_identity_activities_path(ri: "jp")
  end

  test "moved sign mutation routes return gone" do
    patch auth_app_settings_email_url("missing", ri: "jp"), headers: sign_headers

    assert_response :gone

    delete auth_app_settings_email_url("missing", ri: "jp"), headers: sign_headers

    assert_response :gone

    post sign_app_settings_mfa_reset_url(ri: "jp"), headers: sign_headers

    assert_response :gone
  end

  test "sign passkey route still exists" do
    get sign_app_settings_passkeys_url(ri: "jp"), headers: sign_headers

    assert_response :ok
  end

  test "acme identity routes exist and authenticate" do
    get acme_app_identity_url(ri: "jp"), headers: acme_headers_with_session

    assert_response :success

    get acme_app_identity_emails_url(ri: "jp"), headers: acme_headers_with_session

    assert_response :success

    get acme_app_identity_sessions_url(ri: "jp"), headers: acme_headers_with_session

    assert_response :success
  end

  test "acme identity does not depend on sign settings path in overview" do
    get acme_app_identity_url(ri: "jp"), headers: acme_headers_with_session

    assert_response :success
    assert_no_match(/\/settings(?!\/passkeys|\/totps|\/google|\/apple)/, response.body)
  end

  private

  def sign_headers
    {
      "Host" => @sign_host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  def acme_headers
    {
      "Host" => @acme_host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  def acme_headers_with_session
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
    acme_headers
  end
end
