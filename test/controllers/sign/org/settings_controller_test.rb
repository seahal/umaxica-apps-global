# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @acme_host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    host! @host
  end

  test "sign settings shell redirects to acme authority" do
    get sign_org_settings_url(ri: "jp")

    assert_redirected_to acme_org_settings_url(ri: "jp", host: @acme_host)
  end

  test "sign credential settings routes still resolve on sign" do
    get sign_org_settings_passkeys_url(ri: "jp")

    assert_not_equal 404, response.status

    get sign_org_settings_secret_credentials_url(ri: "jp")

    assert_not_equal 404, response.status
  end
end
