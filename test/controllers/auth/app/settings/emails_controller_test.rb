# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Auth::App::Settings::EmailsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_email_statuses, :client_token_kinds

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @acme_host = ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")
    @user = clients(:one)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    mark_token_step_up_satisfied_for_test(@token, scope: "settings_email")
    host! @host
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "sign settings emails index redirects to acme identity" do
    get auth_app_settings_emails_url(ri: "jp"), headers: session_headers

    assert_redirected_to base_app_identity_emails_path(ri: "jp")
  end

  test "sign settings email edit redirects to acme identity" do
    email = ClientEmail.create!(
      address: "sign-email-edit-form@example.com",
      user: clients(:one),
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    get edit_auth_app_settings_email_url(email.public_id, ri: "jp"), headers: session_headers

    assert_redirected_to edit_base_app_identity_email_path(email.public_id, ri: "jp")
  end

  test "sign settings email update is gone" do
    email = ClientEmail.create!(
      address: "sign-email-update-redirect@example.com",
      user: clients(:one),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      promotional: true,
      notifiable: true,
    )

    patch auth_app_settings_email_url(email.public_id, ri: "jp"),
          params: { user_email: { promotional: "0", notifiable: "0" } },
          headers: session_headers

    assert_response :gone
    assert email.reload.promotional
    assert email.reload.notifiable
  end

  test "sign settings email destroy is gone" do
    email = ClientEmail.create!(
      address: "sign-email-destroy-redirect@example.com",
      user: clients(:one),
      user_email_status_id: ClientEmailStatus::UNVERIFIED,
    )

    assert_no_difference("ClientEmail.count") do
      delete auth_app_settings_email_url(email.public_id, ri: "jp"), headers: session_headers
    end

    assert_response :gone
  end

  test "sign email registration route redirects to acme identity" do
    get new_auth_app_settings_emails_registration_url(ri: "jp"), headers: session_headers

    assert_redirected_to new_base_app_identity_emails_registration_path(ri: "jp")
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
