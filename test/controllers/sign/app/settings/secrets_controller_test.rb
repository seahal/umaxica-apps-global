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
      @headers = as_user_headers(@user, host: @host)
    end

    test "renders the missing state for a signed-in owner without a reveal token" do
      get sign_app_settings_secrets_url(ri: "jp"), headers: @headers

      assert_response :success
      assert_select "a[href=?]", sign_app_settings_path(ri: "jp")
      assert_not_includes response.body, "<pre>"
    end

    test "redirects when not signed in" do
      get sign_app_settings_secrets_url(ri: "jp"), headers: { "Host" => @host }

      assert_response :redirect
    end
  end
end
