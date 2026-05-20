# typed: false
# frozen_string_literal: true

require "test_helper"

class Apex::Org::AccountsControllerTest < ActionDispatch::IntegrationTest
  test "GET /accounts redirects to staff oidc authorize" do
    host! ENV["APEX_STAFF_URL"] || "www.org.localhost"

    get apex_org_accounts_url(ri: "jp"), headers: browser_headers

    assert_response :redirect
    assert_match(
      %r{\Ahttp://#{Regexp.escape(ENV.fetch("ID_STAFF_URL", "id.org.localhost"))}/oauth/authorize\?},
      response.location,
    )
    assert_includes response.location, "client_id=apex_org"
    assert_includes response.location, "redirect_uri="
  end
end
