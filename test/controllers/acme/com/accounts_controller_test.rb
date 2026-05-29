# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Com::AccountsControllerTest < ActionDispatch::IntegrationTest
  test "GET /accounts redirects to corporate oidc authorize" do
    host! ENV["ACME_CORPORATE_URL"] || "www.com.localhost"

    get acme_com_accounts_url(ri: "jp"), headers: browser_headers

    assert_response :redirect
    assert_match(%r{\Ahttps://jump\.umaxica\.net/\?rt=}, response.location)
    assert_includes response.location, "rt="
  end
end
