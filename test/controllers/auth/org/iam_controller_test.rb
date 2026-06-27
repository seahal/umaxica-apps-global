# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::IamControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
  end

  test "index redirects to acme org authority" do
    get auth_org_iam_index_url(ri: "jp"), headers: host_headers(@host)

    assert_response :see_other
    uri = URI.parse(response.location)

    assert_equal ENV.fetch("ACME_STAFF_URL", "www.org.localhost"), uri.host
    assert_equal "/iam", uri.path
  end

  test "route path is preserved for compatibility" do
    assert_equal "/iam", auth_org_iam_index_path
  end
end
