# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Org::AccountsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    @staff = operators(:one)
  end

  test "unauthenticated cannot access account" do
    get acme_org_account_url(ri: "jp", host: @host), headers: host_headers(@host)

    assert_response :redirect
  end

  test "index delegates to show" do
    get acme_org_account_url(ri: "jp", host: @host), headers: as_staff_headers(@staff, host: @host)

    assert_response :success
  end

  test "edit renders" do
    get edit_acme_org_account_url(ri: "jp", host: @host), headers: as_staff_headers(@staff, host: @host)

    assert_response :success
  end

  test "update redirects" do
    patch acme_org_account_url(ri: "jp", host: @host), headers: as_staff_headers(@staff, host: @host)

    assert_response :see_other
    assert_redirected_to acme_org_account_url(ri: "jp", host: @host)
  end
end
