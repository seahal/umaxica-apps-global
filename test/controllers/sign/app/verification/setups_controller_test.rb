# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::App::Verification::SetupsControllerTest < ActionDispatch::IntegrationTest
  test "new shows a back link above registration methods when rt is present" do
    host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    user = Client.create!
    headers = as_user_headers(user, host: host)
    rt = Base64.urlsafe_encode64(sign_app_configuration_telephones_path(ri: "jp"))

    get new_sign_app_verification_setup_url(ri: "jp", rt: rt), headers: headers

    assert_response :success
    assert_select "a[href=?]", sign_app_configuration_path(ri: "jp"), text: I18n.t("actions.back")
    assert_operator response.body.index(I18n.t("actions.back")), :<, response.body.index("<ul>")
  end
end
