# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Settings::ActivitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @acme_host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    host! @host
  end

  test "sign settings activities redirects to acme authority" do
    get sign_org_settings_activities_url(ri: "jp")

    assert_redirected_to acme_org_settings_activities_url(ri: "jp", host: @acme_host)
  end
end
