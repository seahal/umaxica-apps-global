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
    uri = URI.parse(jump_rt_url_from_location(response.location))
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal ENV.fetch("ACME_STAFF_URL", "www.org.localhost"), uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal "sign_org", query["client_id"]
    assert_equal OidcClientRegistry.find!("sign_org").redirect_uris.first, query["redirect_uri"]
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
