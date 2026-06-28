# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("AUTH_STAFF_URL")
  end

  test "index redirects to acme org authority" do
    get auth_org_accounts_url(ri: "jp"), headers: host_headers(@host)

    assert_response :see_other
    uri = URI.parse(response.location)

    assert_equal ENV.fetch("ACME_STAFF_URL"), uri.host
    assert_equal "/accounts", uri.path
  end

  test "route path is preserved for compatibility" do
    assert_equal "/accounts", auth_org_accounts_path
  end
end
