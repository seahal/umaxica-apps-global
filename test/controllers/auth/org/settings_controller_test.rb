# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("AUTH_STAFF_URL", "auth.org.localhost")
    @acme_host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    host! @host
  end

  test "sign settings shell stays on sign" do
    get auth_org_settings_url(ri: "jp")

    assert_response :redirect
    assert_oidc_authorize_redirect(response.location, host: @acme_host, client_id: "sign-rp")
  end

  test "sign credential settings routes still resolve on sign" do
    get auth_org_settings_passkeys_url(ri: "jp")

    assert_not_equal 404, response.status

    get auth_org_settings_secret_credentials_url(ri: "jp")

    assert_not_equal 404, response.status
  end
end
