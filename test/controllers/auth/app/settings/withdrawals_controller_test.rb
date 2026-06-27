# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Settings::WithdrawalsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_tokens

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    host! @host
    @user = clients(:one)
    @token = client_tokens(:one)
  end

  def headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  test "new redirects to acme identity withdrawal" do
    get new_sign_app_settings_withdrawal_url(ri: "jp"), headers: headers

    assert_redirected_to new_acme_app_identity_withdrawal_path(ri: "jp")
  end

  test "edit redirects to acme identity withdrawal" do
    get edit_sign_app_settings_withdrawal_url(ri: "jp"), headers: headers

    assert_redirected_to edit_acme_app_identity_withdrawal_path(ri: "jp")
  end

  test "create is gone" do
    post sign_app_settings_withdrawal_url(ri: "jp"), headers: headers

    assert_response :gone
  end

  test "update is gone" do
    patch sign_app_settings_withdrawal_url(ri: "jp"), headers: headers

    assert_response :gone
  end

  test "destroy is gone" do
    delete sign_app_settings_withdrawal_url(ri: "jp"), headers: headers

    assert_response :gone
  end
end
