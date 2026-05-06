# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::Org::ConfigurationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :staffs, :staff_statuses

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    host! @host
    @staff = staffs(:one)
    @headers = { "X-TEST-CURRENT-STAFF" => @staff.id }.freeze
  end

  test "should get show when logged in" do
    get sign_org_configuration_url(ri: "jp"), headers: @headers

    assert_response :success
  end

  test "show includes email telephone and google links" do
    get sign_org_configuration_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "a[href=?]", sign_org_configuration_emails_path(ri: "jp")
    assert_select "a[href=?]", sign_org_configuration_telephones_path(ri: "jp")
    assert_select "a[href=?]", sign_org_configuration_google_path(ri: "jp")
  end

  test "should redirect show when not logged in" do
    get sign_org_configuration_url(ri: "jp")
    rt = Base64.strict_encode64(sign_org_configuration_url(ri: "jp"))

    assert_redirected_to new_sign_org_in_url(rt: rt, host: @host)
  end
end
