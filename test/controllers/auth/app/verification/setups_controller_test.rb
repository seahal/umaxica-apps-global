# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"
require "base64"

class Auth::App::Verification::SetupsControllerTest < ActionDispatch::IntegrationTest
  test "new shows a settings back link above registration methods when pt is present" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    user = Client.create!
    headers = as_user_headers(user, host: host)
    pt = Base64.urlsafe_encode64(auth_app_settings_telephones_path(ri: "jp"))

    get new_auth_app_verification_setup_url(ri: "jp", pt: pt), headers: headers

    assert_response :success
    assert_select "a[href=?]", auth_app_settings_path(ri: "jp"), count: 1
    assert_select "ul"
  end
end
