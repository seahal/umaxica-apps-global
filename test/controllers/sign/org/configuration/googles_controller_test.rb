# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::Org::Configuration::GooglesControllerTest < ActionDispatch::IntegrationTest
  fixtures :staffs, :staff_statuses

  setup do
    @host = ENV.fetch("SIGN_STAFF_URL", "id.org.localhost")
    host! @host
    @staff = staffs(:one)
    @headers = { "Host" => @host, "X-TEST-CURRENT-STAFF" => @staff.id }.freeze
  end

  test "should get show when logged in" do
    get sign_org_configuration_google_url(ri: "jp"), headers: @headers

    assert_response :success
  end

  test "create redirects to google social session" do
    post sign_org_configuration_google_url(ri: "jp"), headers: @headers

    assert_redirected_to start_sign_org_social_authentication_url(provider: "google_org", ri: "jp")
  end

  test "should redirect show when not logged in" do
    get sign_org_configuration_google_url(ri: "jp")
    rt = Base64.urlsafe_encode64(sign_org_configuration_google_url(ri: "jp"))

    assert_redirected_to new_sign_org_in_url(rt: rt, host: @host)
  end
end
