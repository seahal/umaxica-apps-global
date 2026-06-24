# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign::App::Settings
  # Characterizes the recovery-secret reveal page. The owner-self object authorization
  # (ClientPolicy#show?) is additive on top of authenticate_client! + the one-time reveal token,
  # so the allowed-actor behavior must stay unchanged.
  class SecretsControllerTest < ActionDispatch::IntegrationTest
    fixtures :clients, :client_statuses

    setup do
      @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
      host! @host
      @user = clients(:one)
      @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      satisfy_user_verification(@token)
      access_token = AuthenticationToken.encode(
        @user,
        host: @host,
        session_public_id: @token.public_id,
      )
      @headers = as_user_headers(@user, host: @host, session_public_id: @token.public_id).merge(
        "Authorization" => "Bearer #{access_token}",
      )
      @session_public_id = @token.public_id
    end

    test "renders the missing state for a signed-in owner without a reveal token" do
      get sign_app_settings_secrets_url(ri: "jp"), headers: @headers

      assert_response :success
      assert_select "title", text: /#{I18n.t("sign.recovery_passcodes.show.title")}/
      assert_select "a[href=?]", sign_app_settings_path(ri: "jp")
      assert_not_includes response.body, "<pre>"
    end

    test "redirects when not signed in" do
      get sign_app_settings_secrets_url(ri: "jp"), headers: { "Host" => @host }

      assert_response :redirect
    end

    test "reveals multiple recovery passcodes once" do
      issued = IdentityOneTimeReveal.issue!(
        actor: @user,
        session_nonce: @user.public_id,
        value: %w(recovery-1 recovery-2 recovery-3),
        purpose: "client.recovery_secret_credential",
      )

      assert_equal %w(recovery-1 recovery-2 recovery-3),
                   IdentityOneTimeReveal.consume!(
                     actor: @user,
                     session_nonce: @user.public_id,
                     token: issued.token,
                     purpose: "client.recovery_secret_credential",
                   ).value

      issued = IdentityOneTimeReveal.issue!(
        actor: @user,
        session_nonce: @user.public_id,
        value: %w(recovery-1 recovery-2 recovery-3),
        purpose: "client.recovery_secret_credential",
      )

      get sign_app_settings_secrets_url(ri: "jp", token: issued.token), headers: @headers

      assert_response :success
      assert_select "title", text: /#{I18n.t("sign.recovery_passcodes.show.title")}/
      assert_includes response.body, "recovery-1"
      assert_includes response.body, "recovery-2"
      assert_includes response.body, "recovery-3"
      assert_includes response.body,
                      I18n.t("sign.recovery_passcodes.show.one_time_notice")

      get sign_app_settings_secrets_url(ri: "jp", token: issued.token), headers: @headers

      assert_response :success
      assert_includes response.body,
                      I18n.t("sign.recovery_passcodes.show.missing")
      assert_not_includes response.body, "recovery-1"
    end
  end
end
