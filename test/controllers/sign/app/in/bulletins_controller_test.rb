# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::App::In::BulletinsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :user_tokens

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = users(:one)
  end

  test "show without login is rejected" do
    get sign_app_in_bulletin_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
  end

  test "show without bulletin returns forbidden" do
    get sign_app_in_bulletin_url(ri: "jp"),
        headers: as_user_headers(@user, host: @host)

    assert_response :forbidden
    assert_equal I18n.t("sign.app.in.bulletins.forbidden"), response.body
  end

  test "show with bulletin returns success" do
    get sign_app_in_bulletin_url(ri: "jp"),
        headers: as_user_headers(@user, host: @host).merge(
          "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "new"),
        )

    assert_response :success
  end

  test "update refreshes state and issued_at then redirects to show" do
    previous_issued_at = 10.minutes.ago.to_i

    patch sign_app_in_bulletin_url(ri: "jp"),
          headers: as_user_headers(@user, host: @host).merge(
            "X-TEST-BULLETIN" => bulletin_json(issued_at: previous_issued_at, state: "new"),
          )

    assert_redirected_to sign_app_in_bulletin_path(ri: "jp")
    assert_equal "updated", session[:in_bulletin]["state"]
    assert_operator session[:in_bulletin]["issued_at"], :>, previous_issued_at
  end

  test "destroy consumes bulletin and redirects to rd" do
    rd = Base64.urlsafe_encode64("/configuration?ri=jp")

    delete sign_app_in_bulletin_url(ri: "jp", rd: rd),
           headers: as_user_headers(@user, host: @host).merge(
             "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "updated"),
           )

    assert_nil session[:in_bulletin]
    assert_redirected_to "/configuration?ri=jp"
  end

  test "destroy without rd redirects to default" do
    delete sign_app_in_bulletin_url(ri: "jp"),
           headers: as_user_headers(@user, host: @host).merge(
             "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "updated"),
           )

    assert_nil session[:in_bulletin]
    assert_redirected_to sign_app_configuration_path(ri: "jp")
  end

  test "show and update return timeout when expired" do
    expired_at = 2.hours.ago.to_i - 1

    get sign_app_in_bulletin_url(ri: "jp"),
        headers: as_user_headers(@user, host: @host).merge(
          "X-TEST-BULLETIN" => bulletin_json(issued_at: expired_at, state: "new"),
        )

    assert_response :request_timeout

    # New request; session already has expired bulletin from previous request
    patch sign_app_in_bulletin_url(ri: "jp"),
          headers: as_user_headers(@user, host: @host)

    assert_response :request_timeout
  end

  test "destroy still redirects when expired" do
    rd = Base64.urlsafe_encode64("/configuration")

    delete sign_app_in_bulletin_url(ri: "jp", rd: rd),
           headers: as_user_headers(@user, host: @host).merge(
             "X-TEST-BULLETIN" => bulletin_json(issued_at: 2.hours.ago.to_i - 1, state: "updated"),
           )

    assert_redirected_to "/configuration"
  end

  private

  def bulletin_json(issued_at:, state:)
    { "issued_at" => issued_at, "kind" => "mock", "state" => state }.to_json
  end
end
