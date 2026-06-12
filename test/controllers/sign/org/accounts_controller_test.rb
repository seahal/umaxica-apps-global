# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::AccountsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
  end

  test "index redirects when not signed in" do
    get sign_org_accounts_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
    uri = URI.parse(jump_rt_url_from_location(response.location))
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal ENV.fetch("ACME_STAFF_URL", "www.org.localhost"), uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal "sign_org", query["client_id"]
    assert_equal OidcClientRegistry.find!("sign_org").redirect_uris.first, query["redirect_uri"]
  end

  test "index renders when signed in" do
    get sign_org_accounts_url(ri: "jp"), headers: as_staff_headers(@staff, host: @host)

    assert_response :success
    assert_equal "ok", response.body
  end

  test "management routes are index resources" do
    assert_equal "/accounts", sign_org_accounts_path
    assert_equal "/iam", sign_org_iam_index_path
    assert_equal "/system", sign_org_system_index_path
    assert_equal "/audit", sign_org_audit_index_path
    assert_equal "/support", sign_org_support_index_path
    assert_equal "/billing", sign_org_billing_index_path
  end
end
