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

  test "sign_out_get_redirect_is_not_session_mutation" do
    token = ClientToken.create!(user: @user)

    get sign_app_sign_out_url(ri: "jp"), headers: session_headers(token)

    assert_redirect_to_acme_sign_out
    assert_predicate token.reload, :currently_usable?
  end

  test "sign_out_post_redirect_uses_acme_authority" do
    token = ClientToken.create!(user: @user)

    post sign_app_sign_out_url(ri: "jp"), params: { confirm: "1" }, headers: session_headers(token)

    assert_redirect_to_acme_sign_out
    assert_predicate token.reload, :currently_usable?
  end

  test "sign_out_destroy_redirect_is_not_session_mutation" do
    token = ClientToken.create!(user: @user)

    delete sign_app_sign_out_url(ri: "jp"), headers: session_headers(token)

    assert_redirect_to_acme_sign_out
    assert_predicate token.reload, :currently_usable?
  end

  test "sign_out_redirect_target_is_not_user_controlled" do
    get sign_app_sign_out_url(ri: "jp", return_to: "https://evil.example/logout"),
        headers: { "Host" => @host }

    assert_redirect_to_acme_sign_out
  end

  private

  def session_headers(token)
    {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end

  def assert_redirect_to_acme_sign_out
    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal @acme_host, location.host
    assert_equal "/sign/out", location.path
    assert_equal "ri=jp", location.query
  end
end
