# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @acme_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    host! @host
  end

  test "sign settings shell stays on sign" do
    get sign_com_settings_url(ri: "jp")

    assert_response :redirect
    assert_not_equal @acme_host, URI.parse(response.location).host
  end

  test "sign credential settings routes still resolve on sign" do
    get sign_com_settings_passkeys_url(ri: "jp")

    assert_not_equal 404, response.status

    get sign_com_settings_secret_credentials_url(ri: "jp")

    assert_not_equal 404, response.status
  end
end
