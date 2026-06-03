# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Settings::ActivitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    host! @host
  end

  test "sign settings activities redirects to acme authority" do
    get sign_app_settings_activities_url(ri: "jp")

    assert_redirected_to acme_app_settings_activities_url(ri: "jp", host: @acme_host)
  end
end
