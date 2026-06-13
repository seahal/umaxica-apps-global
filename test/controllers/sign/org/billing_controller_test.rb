# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::BillingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
  end

  test "index redirects to acme org authority" do
    get sign_org_billing_index_url(ri: "jp"), headers: host_headers(@host)

    assert_response :see_other
    uri = URI.parse(response.location)
    assert_equal ENV.fetch("ACME_STAFF_URL", "www.org.localhost"), uri.host
    assert_equal "/billing", uri.path
  end

  test "route path is preserved for compatibility" do
    assert_equal "/billing", sign_org_billing_index_path
  end
end
