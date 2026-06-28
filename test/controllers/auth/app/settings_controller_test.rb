# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("AUTH_SERVICE_URL", "auth.app.localhost")
    @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    host! @host
  end

  test "anonymous sign settings shell requires sign authentication" do
    get auth_app_settings_url(ri: "jp")

    assert_response :redirect
    assert_oidc_authorize_redirect(response.location, host: @acme_host, client_id: "sign-rp")
  end

  test "sign credential settings routes still resolve on sign" do
    get auth_app_settings_passkeys_url(ri: "jp")

    assert_not_equal 404, response.status

    get auth_app_settings_secret_credentials_url(ri: "jp")

    assert_not_equal 404, response.status
  end
end
