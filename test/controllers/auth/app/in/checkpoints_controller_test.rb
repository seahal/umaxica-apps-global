# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Auth::App::Sign::In::CheckpointsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_tokens

  setup do
    @host = ENV.fetch("AUTH_SERVICE_URL", "auth.app.localhost")
    @user = clients(:one)
  end

  test "show without login is rejected" do
    get auth_app_sign_in_check_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
  end

  test "show without sign in sequence is rejected" do
    get auth_app_sign_in_check_url(ri: "jp"),
        headers: as_user_headers(@user, host: @host)

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.messages.not_authorized")
  end

  test "update without sign in sequence is rejected" do
    patch auth_app_sign_in_check_url(ri: "jp"),
          headers: as_user_headers(@user, host: @host).merge(
            "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "new"),
          )

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.messages.not_authorized")
  end

  test "destroy is rejected by routing" do
    pt = Base64.urlsafe_encode64("/settings")

    delete auth_app_sign_in_check_url(ri: "jp", pt: pt),
           headers: as_user_headers(@user, host: @host).merge(
             "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "updated"),
           )

    assert_response :not_found
  end

  private

  def bulletin_json(issued_at:, state:)
    { "issued_at" => issued_at, "kind" => "mock", "state" => state }.to_json
  end
end
