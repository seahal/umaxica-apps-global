# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Settings::ActivitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @acme_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    host! @host
  end

  test "sign settings activities redirects to acme authority" do
    get sign_com_settings_activities_url(ri: "jp")

    assert_redirected_to acme_com_settings_activities_url(ri: "jp", host: @acme_host)
  end
end
