# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::App::AccountsControllerTest < ActionDispatch::IntegrationTest
  test "GET /accounts redirects to app oidc authorize" do
    host! ENV["ACME_SERVICE_URL"] || "www.app.localhost"

    get acme_app_accounts_url(ri: "jp"), headers: browser_headers

    assert_response :redirect
    assert_match(%r{\Ahttps://jump\.umaxica\.net/\?rt=}, response.location)
    assert_includes response.location, "rt="
  end
end
