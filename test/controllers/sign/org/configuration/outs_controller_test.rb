# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Configuration::OutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :staffs, :staff_statuses

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = staffs(:one)
    @host = ENV["ID_STAFF_URL"] || "id.org.localhost"
  end

  test "should get edit raises error without session" do
    get edit_sign_org_configuration_out_url(ri: "jp"), headers: { "Host" => @host }

    rt = Base64.urlsafe_encode64(edit_sign_org_configuration_out_url(ri: "jp", host: @host))

    assert_redirected_to new_sign_org_in_url(rt: rt, host: @host)
  end

  test "should destroy raises error without session" do
    delete sign_org_configuration_out_url(ri: "jp"), headers: { "Host" => @host }

    rt = Base64.urlsafe_encode64(sign_org_configuration_out_url(ri: "jp", host: @host))

    assert_redirected_to new_sign_org_in_url(rt: rt, host: @host)
  end

  test "should destroy with staff session even without step-up verification" do
    token = StaffToken.create!(staff: @staff)
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    delete sign_org_configuration_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-STAFF" => @staff.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_redirected_to sign_org_root_path(ri: "jp")
    assert_not StaffToken.exists?(id: token.id)
  end

  test "logout clears all auth cookies" do
    token = StaffToken.create!(staff: @staff)
    refresh_plain = token.rotate_refresh_token!

    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = "test_access_token"
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain
    cookies[Authentication::Base::DBSC_COOKIE_KEY] = "test_dbsc_value"

    delete sign_org_configuration_out_url(ri: "jp"),
           headers: { "Host" => @host,
                      "X-TEST-CURRENT-STAFF" => @staff.id,
                      "X-TEST-SESSION-PUBLIC-ID" => token.public_id, }

    assert_redirected_to sign_org_root_path(ri: "jp")

    # All auth cookies must be cleared after logout
    assert_empty cookies[Authentication::Base::ACCESS_COOKIE_KEY].to_s
    assert_empty cookies[Authentication::Base::REFRESH_COOKIE_KEY].to_s
    assert_empty cookies[Authentication::Base::DBSC_COOKIE_KEY].to_s
  end
end
