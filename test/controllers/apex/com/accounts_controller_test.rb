# typed: false
# frozen_string_literal: true

require "test_helper"

class Apex::Com::AccountsControllerTest < ActionDispatch::IntegrationTest
  test "GET /accounts redirects to corporate oidc authorize" do
    host! ENV["APEX_CORPORATE_URL"] || "www.com.localhost"

    get apex_com_accounts_url(ri: "jp"), headers: browser_headers

    assert_response :redirect
    assert_match(
      %r{\Ahttp://#{Regexp.escape(ENV.fetch("ID_CORPORATE_URL", "id.com.localhost"))}/oauth/authorize\?},
      response.location,
    )
    assert_includes response.location, "client_id=apex_com"
    assert_includes response.location, "redirect_uri="
  end
end
