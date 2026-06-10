# typed: false
# frozen_string_literal: true

require "test_helper"

# SupportController is a staff-only (`AUTHENTICATION_MODE = :private`) read-only stub.
# It performs an object-level Action Policy check against the current operator record.
class Sign::Org::SupportControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :clients

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
    @client = clients(:one)
  end

  test "index redirects when not signed in" do
    get sign_org_support_index_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
    assert_match %r{\Ahttps://id\.umaxica\.org/sign/in/entrance\?ri=jp\z}, jump_rt_url_from_location(response.location)
  end

  test "index renders for authenticated operator authorized on own record" do
    get sign_org_support_index_url(ri: "jp"), headers: as_staff_headers(@staff, host: @host)

    assert_response :success
    assert_equal "ok", response.body
  end

  test "client credentials do not authenticate as operator on the staff surface" do
    get sign_org_support_index_url(ri: "jp"), headers: as_user_headers(@client, host: @host)

    assert_response :redirect
  end
end
