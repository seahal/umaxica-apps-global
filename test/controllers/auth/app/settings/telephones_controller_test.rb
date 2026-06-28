# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../../../support/auth_helpers"

# Auth::App::Settings::TelephonesController is now a redirect shim.
# Read actions redirect to base/app/identity/telephones/*.
# Write actions return 410 Gone.
class Auth::App::Settings::TelephonesControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_telephone_statuses
  include AuthHelpers

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    host! @host
    @user = clients(:one)
    @token = ClientToken.create!(user_id: @user.id)
    satisfy_user_verification(@token)
    set_access_cookie(jwt_access_token_for(@user, host: @host, session_public_id: @token.public_id))
  end

  def request_headers
    as_user_headers(@user, host: @host, session_public_id: @token.public_id)
  end

  test "index redirects to base app identity telephones" do
    get auth_app_settings_telephones_url(ri: "jp"), headers: request_headers

    assert_response :see_other
    assert_redirected_to base_app_identity_telephones_path(ri: "jp")
  end

  test "new redirects to base app identity telephones registration" do
    get new_auth_app_settings_telephone_url(ri: "jp"), headers: request_headers

    assert_response :see_other
    assert_redirected_to new_base_app_identity_telephones_registration_path(ri: "jp")
  end

  test "edit redirects to base app identity telephone edit" do
    telephone = ClientTelephone.create!(
      number: "+10000000031",
      user: @user,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    get edit_auth_app_settings_telephone_url(telephone.public_id, ri: "jp"), headers: request_headers

    assert_response :see_other
    assert_redirected_to edit_base_app_identity_telephone_path(telephone.public_id, ri: "jp")
  end

  test "create returns 410 Gone" do
    post auth_app_settings_telephones_url(ri: "jp"),
         params: { user_telephone: { raw_number: "+10000000008" } },
         headers: request_headers

    assert_response :gone
  end

  test "destroy returns 410 Gone" do
    telephone = ClientTelephone.create!(
      number: "+10000000000",
      user: @user,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    delete auth_app_settings_telephone_url(telephone.public_id, ri: "jp"), headers: request_headers

    assert_response :gone
  end

  test "index requires authentication" do
    get auth_app_settings_telephones_url(ri: "jp")

    assert_response :redirect
  end
end
