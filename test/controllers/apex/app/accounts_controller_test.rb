# typed: false
# frozen_string_literal: true

require "test_helper"

class Apex::App::AccountsControllerTest < ActionDispatch::IntegrationTest
  test "GET /accounts redirects to app oidc authorize" do
    host! ENV["APEX_SERVICE_URL"] || "www.app.localhost"

    get apex_app_accounts_url(ri: "jp"), headers: browser_headers

    assert_response :redirect
    assert_match(
      %r{\Ahttp://#{Regexp.escape(ENV.fetch("ID_SERVICE_URL", "id.app.localhost"))}/oauth/authorize\?},
      response.location,
    )
    assert_includes response.location, "client_id=apex_app"
    assert_includes response.location, "redirect_uri="
  end
end
