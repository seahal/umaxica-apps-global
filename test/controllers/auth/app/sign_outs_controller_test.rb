# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")
    host! @host
  end

  test "get sign out redirects to acme entry" do
    get new_auth_app_sign_out_url(host: @host, ri: "jp")

    assert_response :see_other
    assert_equal new_auth_app_sign_out_url(host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), protocol: "https"),
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

    post auth_app_sign_out_url(host: @host, logout_token: raw_token), headers: browser_headers.merge(
      "Host" => @host,
      **as_user_headers(user, host: @host, session_public_id: token.public_id),
    )

    assert_response :see_other
    assert_equal(
      complete_auth_app_sign_out_url(
        host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), protocol: "https",
      ),
      response.location,
    )
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

    post auth_app_sign_out_url(host: @host, logout_token: raw_token)

    assert_response :see_other
    assert_equal(
      complete_auth_app_sign_out_url(
        host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), protocol: "https",
      ),
      response.location,
    )
  end

  test "invalid token does not external redirect" do
    post auth_app_sign_out_url(host: @host, logout_token: "invalid"), headers: browser_headers.merge("Host" => @host)

    assert_response :see_other
    uri = URI.parse(response.location)

    assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), uri.host
    assert_equal "/sign/out/complete", uri.path
  end

  test "destroy cancels the pending logout and keeps the current session" do
    user = create_verified_user_with_email(email_address: "sign-cancel@example.com")
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!
    transaction =
      AcmeLogoutTransactionCoordinator.issue!(
        origin_surface: "sign",
        initiating_client_id: "sign-rp",
        completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(
          origin_surface: "sign",
          ri: "jp",
          surface: "app",
        ),
        surface: "app",
        ri: "jp",
      ).transaction

    delete auth_app_sign_out_url(ri: "jp", host: @host, logout_challenge: transaction.logout_challenge),
           headers: browser_headers.merge("Host" => @host)

    assert_response :see_other
    assert_equal auth_app_root_url(ri: "jp", host: @host), response.location
    assert_predicate token.reload, :currently_usable?
    assert_predicate transaction.reload, :failed?

    delete auth_app_sign_out_url(ri: "jp", host: @host, logout_challenge: transaction.logout_challenge),
           headers: browser_headers.merge("Host" => @host)

    assert_response :see_other
    assert_equal auth_app_root_url(ri: "jp", host: @host), response.location
    assert_predicate token.reload, :currently_usable?
    assert_predicate transaction.reload, :failed?
  end

  test "destroy returns no content for json without revoking the current session" do
    user = create_verified_user_with_email(email_address: "sign-json-cancel@example.com")
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!
    transaction =
      AcmeLogoutTransactionCoordinator.issue!(
        origin_surface: "sign",
        initiating_client_id: "sign-rp",
        completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(
          origin_surface: "sign",
          ri: "jp",
          surface: "app",
        ),
        surface: "app",
        ri: "jp",
      ).transaction

    delete auth_app_sign_out_url(ri: "jp", host: @host, format: :json, logout_challenge: transaction.logout_challenge),
           headers: browser_headers.merge("Host" => @host)

    assert_response :no_content
    assert_predicate token.reload, :currently_usable?
    assert_predicate transaction.reload, :failed?

    delete auth_app_sign_out_url(ri: "jp", host: @host, format: :json, logout_challenge: transaction.logout_challenge),
           headers: browser_headers.merge("Host" => @host)

    assert_response :no_content
    assert_predicate token.reload, :currently_usable?
    assert_predicate transaction.reload, :failed?
  end
end
