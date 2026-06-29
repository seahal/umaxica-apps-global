# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

# Auth::App::Settings::ActivitiesController is a redirect shim to base/app/identity/activities.
class Auth::App::Settings::ActivitiesControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @user = clients(:one)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    host! @host
  end

  test "sign settings activities redirects to base identity activities" do
    get auth_app_settings_activities_url(ri: "jp"), headers: session_headers

    assert_response :see_other
    assert_redirected_to base_app_identity_activities_path(ri: "jp")
  end

  private

  def session_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end
end
