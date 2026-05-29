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
    assert_match %r{\Ahttps://id\.umaxica\.org/sign/in/new\?ri=jp\z}, jump_rt_url_from_location(response.location)
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
