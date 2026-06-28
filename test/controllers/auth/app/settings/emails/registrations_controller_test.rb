# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Settings::Emails::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("AUTH_SERVICE_URL", "auth.app.localhost")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    satisfy_user_verification(@token)
  end

  test "new redirects to acme identity email registration" do
    get new_auth_app_settings_emails_registration_url(ri: "jp"), headers: session_headers

    assert_redirected_to new_base_app_identity_emails_registration_path(ri: "jp")
  end

  test "edit redirects to acme identity email registration" do
    get edit_auth_app_settings_emails_registration_url(ri: "jp"), headers: session_headers

    assert_redirected_to edit_base_app_identity_emails_registration_path(ri: "jp")
  end

  test "create is gone" do
    post auth_app_settings_emails_registration_url(ri: "jp"), headers: session_headers

    assert_response :gone
  end

  test "update is gone" do
    patch auth_app_settings_emails_registration_url(ri: "jp"), headers: session_headers

    assert_response :gone
  end

  test "redelivery is gone" do
    post auth_app_settings_emails_registration_redelivery_url(ri: "jp"), headers: session_headers

    assert_response :gone
  end

  private

  def session_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end
end
