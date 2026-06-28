# typed: false
# frozen_string_literal: true

require "test_helper"

module Auth::App::Settings
  # Auth::App::Settings::SecretsController is a redirect shim to base/app/identity/recovery-secret.
  class SecretsControllerTest < ActionDispatch::IntegrationTest
    fixtures :clients, :client_statuses

    setup do
      @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
      host! @host
      @user = clients(:one)
      @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      satisfy_user_verification(@token)
      @headers = as_user_headers(@user, host: @host, session_public_id: @token.public_id)
    end

    test "show redirects to base identity recovery secret" do
      get auth_app_settings_secrets_url(ri: "jp"), headers: @headers

      assert_response :see_other
      assert_redirected_to base_app_identity_recovery_secret_path(ri: "jp")
    end

    test "show with token redirects preserving token" do
      token_param = "test-token-value"
      get auth_app_settings_secrets_url(ri: "jp", token: token_param), headers: @headers

      assert_response :see_other
      assert_redirected_to base_app_identity_recovery_secret_path(ri: "jp", token: token_param)
    end

    test "redirects when not signed in" do
      get auth_app_settings_secrets_url(ri: "jp"), headers: { "Host" => @host }

      assert_response :redirect
    end
  end
end
