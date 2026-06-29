# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

# Auth::App::Settings::SecretCredentialsController is now a redirect shim.
# Read actions (index/show/new/edit) redirect to base/app/identity/secrets/*.
# Write actions (create/update/destroy) return 410 Gone.
class Auth::App::Settings::SecretCredentialsControllerTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses, :client_secret_credential_statuses,
           :client_secret_credential_kinds, :client_email_statuses,
           :client_chronicle_events, :client_chronicle_levels

  setup do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "scu_#{SecureRandom.hex(4)}",
    )
    @token = ClientToken.create!(user_id: @user.id)
    satisfy_user_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_secret_credential")
    ClientEmail.create!(
      user: @user,
      address: "secret_credential-user@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    @user_secret_credential = ClientSecretCredential.create!(
      user: @user,
      name: "Test Secret",
      password_digest: "test_password_digest",
      last_used_at: Time.zone.now,
      user_secret_kind_id: ClientSecretCredentialKinds::LOGIN,
    )
  end

  def authenticated_headers
    browser_headers.merge(
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    )
  end

  test "index redirects to base app identity secrets" do
    get auth_app_settings_secret_credentials_url(ri: "jp"), headers: authenticated_headers

    assert_response :see_other
    assert_redirected_to base_app_identity_secrets_path(ri: "jp")
  end

  test "show redirects to base app identity secret" do
    get auth_app_settings_secret_credential_url(@user_secret_credential.public_id, ri: "jp"),
        headers: authenticated_headers

    assert_response :see_other
    assert_redirected_to base_app_identity_secret_path(@user_secret_credential.public_id, ri: "jp")
  end

  test "new redirects to base app new identity secret" do
    get new_auth_app_settings_secret_credential_url(ri: "jp"), headers: authenticated_headers

    assert_response :see_other
    assert_redirected_to new_base_app_identity_secret_path(ri: "jp")
  end

  test "edit redirects to base app edit identity secret" do
    get edit_auth_app_settings_secret_credential_url(@user_secret_credential.public_id, ri: "jp"),
        headers: authenticated_headers

    assert_response :see_other
    assert_redirected_to edit_base_app_identity_secret_path(@user_secret_credential.public_id, ri: "jp")
  end

  test "create returns 410 Gone" do
    post auth_app_settings_secret_credentials_url(ri: "jp"),
         params: { user_secret_credential: { name: "New", enabled: true } },
         headers: authenticated_headers

    assert_response :gone
  end

  test "update returns 410 Gone" do
    patch auth_app_settings_secret_credential_url(@user_secret_credential.public_id, ri: "jp"),
          params: { user_secret_credential: { name: "Updated" } },
          headers: authenticated_headers

    assert_response :gone
  end

  test "destroy returns 410 Gone" do
    delete auth_app_settings_secret_credential_url(@user_secret_credential.public_id, ri: "jp"),
           headers: authenticated_headers

    assert_response :gone
  end

  test "index requires authentication" do
    get auth_app_settings_secret_credentials_url(ri: "jp")

    assert_response :redirect
  end
end
