# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::SignOutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @user = clients(:one)
  end

  test "sign out confirmation does not mutate the session" do
    token = ClientToken.create!(user: @user)

    get sign_app_sign_out_confirmation_url(ri: "jp"), headers: session_headers(token)

    assert_response :success
    assert_predicate token.reload, :currently_usable?
  end

  test "sign out attempt logs out and shows completion" do
    token = ClientToken.create!(user: @user)

    post sign_app_sign_out_attempt_url(ri: "jp"), params: { confirm: "1" }, headers: session_headers(token)

    assert_redirected_to sign_app_sign_out_completion_url(ri: "jp")
  end

  test "sign out attempt without confirmation redirects back without mutation" do
    token = ClientToken.create!(user: @user)

    post sign_app_sign_out_attempt_url(ri: "jp"), headers: session_headers(token)

    assert_redirected_to sign_app_sign_out_confirmation_url(ri: "jp")
    assert_predicate token.reload, :currently_usable?
  end

  test "sign_out_redirect_target_is_not_user_controlled" do
    token = ClientToken.create!(user: @user)

    get sign_app_sign_out_confirmation_url(ri: "jp", return_to: "https://evil.example/logout"),
        headers: session_headers(token)

    assert_response :success
    assert_no_match("evil.example", response.body)
  end

  private

  def session_headers(token)
    {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end
end
