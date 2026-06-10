# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::App::In::CheckpointsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_tokens

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = clients(:one)
  end

  test "show without login is rejected" do
    get sign_app_sign_in_check_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
  end

  test "show without sign in sequence is rejected" do
    get sign_app_sign_in_check_url(ri: "jp"),
        headers: as_user_headers(@user, host: @host)

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.messages.not_authorized")
  end

  test "update without sign in sequence is rejected" do
    patch sign_app_sign_in_check_url(ri: "jp"),
          headers: as_user_headers(@user, host: @host).merge(
            "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "new"),
          )

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.messages.not_authorized")
  end

  test "destroy without sign in sequence is rejected" do
    pt = Base64.urlsafe_encode64("/settings")

    delete sign_app_sign_in_check_url(ri: "jp", pt: pt),
           headers: as_user_headers(@user, host: @host).merge(
             "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "updated"),
           )

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.messages.not_authorized")
  end

  private

  def bulletin_json(issued_at:, state:)
    { "issued_at" => issued_at, "kind" => "mock", "state" => state }.to_json
  end
end
