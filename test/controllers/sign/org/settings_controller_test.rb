# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::Org::SettingssControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    host! @host
    @staff = operators(:one)
    @headers = { "X-TEST-CURRENT-STAFF" => @staff.id }.freeze
  end

  test "should get show when logged in" do
    get sign_org_settings_url(ri: "jp"), headers: @headers

    assert_response :success
  end

  test "show includes local account links and no social provider links" do
    get sign_org_settings_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "a[href=?]", sign_org_settings_emails_path(ri: "jp")
    assert_select "a[href=?]", sign_org_settings_telephones_path(ri: "jp")
    assert_select "a[href=?]", sign_org_settings_birthdate_path(ri: "jp")
    assert_select "a[href*=?]", "/settings/google", count: 0
  end

  test "should redirect show when not logged in" do
    get sign_org_settings_url(ri: "jp")

    assert_match %r{\Ahttps://id\.umaxica\.org/sign/in/new\?ri=jp\z}, jump_rt_url_from_location(response.location)
  end
end
