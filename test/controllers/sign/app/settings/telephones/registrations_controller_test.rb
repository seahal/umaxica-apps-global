# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Settings::Telephones::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    satisfy_user_verification(@token)
  end

  test "new redirects to acme identity telephones registration" do
    get new_sign_app_settings_telephones_registration_url(ri: "jp"), headers: session_headers

    assert_redirected_to new_acme_app_identity_telephones_registration_path(ri: "jp")
  end

  test "edit redirects to acme identity telephones registration" do
    get edit_sign_app_settings_telephones_registration_url(ri: "jp"), headers: session_headers

    assert_redirected_to edit_acme_app_identity_telephones_registration_path(ri: "jp")
  end

  test "create is gone" do
    post sign_app_settings_telephones_registration_url(ri: "jp"),
         params: { user_telephone: { raw_number: "+10000000009" } },
         headers: session_headers

    assert_response :gone
  end

  test "update is gone" do
    patch sign_app_settings_telephones_registration_url(ri: "jp"),
          params: { user_telephone: { pass_code: "123456" } },
          headers: session_headers

    assert_response :gone
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
