# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")
    host! @host
  end

  test "get sign out redirects to acme entry" do
    get new_sign_app_sign_out_url(host: @host, ri: "jp")

    assert_response :see_other
    assert_equal new_acme_app_sign_out_url(host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), protocol: "https"),
                 response.location
  end

  test "post sign out consumes one-time token and redirects to acme complete" do
    user = create_verified_user_with_email(email_address: "sign-cleanup@example.com")
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    transaction, raw_token = LogoutTransaction.issue!(
      issuer: "acme",
      audience: "sign_app",
      purpose: "sign_out",
      expires_in: 1.minute,
    )
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post sign_app_sign_out_url(host: @host, logout_token: raw_token), headers: browser_headers.merge(
      "Host" => @host,
      **as_user_headers(user, host: @host, session_public_id: token.public_id),
    )

    assert_response :see_other
    assert_equal complete_acme_app_sign_out_url(host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), protocol: "https"),
                 response.location
    assert_predicate transaction.reload.consumed_at, :present?
    assert_predicate token.reload, :revoked?
  end

  test "consumed token reuse remains idempotent and still redirects to acme complete" do
    transaction, raw_token = LogoutTransaction.issue!(
      issuer: "acme",
      audience: "sign_app",
      purpose: "sign_out",
      expires_in: 1.minute,
    )
    transaction.update!(consumed_at: Time.current)

    post sign_app_sign_out_url(host: @host, logout_token: raw_token)

    assert_response :see_other
    assert_equal complete_acme_app_sign_out_url(host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), protocol: "https"),
                 response.location
  end

  test "invalid token does not external redirect" do
    post sign_app_sign_out_url(host: @host, logout_token: "invalid"), headers: browser_headers.merge("Host" => @host)

    assert_response :see_other
    uri = URI.parse(response.location)

    assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), uri.host
    assert_equal "/sign/out/complete", uri.path
  end

  test "destroy shims to acme entry" do
    delete sign_app_sign_out_url(host: @host), headers: browser_headers.merge("Host" => @host)

    assert_response :see_other
    assert_equal new_acme_app_sign_out_url(host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), protocol: "https"),
                 response.location
  end
end
