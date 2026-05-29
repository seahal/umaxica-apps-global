# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Org::AccountsControllerTest < ActionDispatch::IntegrationTest
  test "GET /accounts redirects to staff oidc authorize" do
    host! ENV["ACME_STAFF_URL"] || "www.org.localhost"

    get acme_org_accounts_url(ri: "jp"), headers: browser_headers

    assert_response :redirect
    assert_match(%r{\Ahttps://jump\.umaxica\.net/\?rt=}, response.location)
    assert_includes response.location, "rt="
  end
end
