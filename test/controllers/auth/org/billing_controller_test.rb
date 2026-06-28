# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::BillingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
  end

  test "index redirects to acme org authority" do
    get auth_org_billing_index_url(ri: "jp"), headers: host_headers(@host)

    assert_response :see_other
    uri = URI.parse(response.location)

    assert_equal "log.umaxica.org", uri.host
    assert_equal "/billing", uri.path
  end

  test "route path is preserved for compatibility" do
    assert_equal "/billing", auth_org_billing_index_path
  end
end
