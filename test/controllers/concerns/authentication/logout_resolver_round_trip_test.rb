# typed: false
# frozen_string_literal: true

require "test_helper"

# Reproduction probe: does an ordinary sign-out actually make the access token
# stop resolving a current resource on the *next* request? This exercises the
# server-side contract between AuthenticationLogoutCurrentSession (revocation)
# and AuthenticationCurrentResourceResolver (per-request resolution), with no
# views or HTTP caching involved.
class AuthenticationLogoutResolverRoundTripTest < ActiveSupport::TestCase
  fixtures :clients, :client_token_statuses, :client_token_kinds

  test "access token stops resolving a resource after current-session logout" do
    host = ENV.fetch("ID_SERVICE_URL")
    user = clients(:one)

    headers = authenticated_headers_for(user, host: host)
    access_token = headers["Authorization"].sub(/\ABearer /, "")
    session_public_id = headers["X-TEST-SESSION-PUBLIC-ID"]

    resolve =
      lambda do
        AuthenticationCurrentResourceResolver.new(
          access_token: access_token,
          request_host: host,
          resource_type: auth_resource_type_for(user),
          resource_class: Client,
          token_class: ClientToken,
          authorization_scheme: "Bearer",
          dpop_proof: nil,
          request_method: "GET",
          request_uri: "https://#{host}/",
          jwt_issuer_id: jwt_issuer_id_for_test_host(host, auth_resource_type_for(user)),
        ).call
      end

    assert_equal user.id, resolve.call.resource&.id, "should be signed in before logout"

    AuthenticationLogoutCurrentSession.call(
      resource: user,
      token_class: ClientToken,
      session_public_id: session_public_id,
      reason: "user_logout",
    )

    assert_nil resolve.call.resource, "should be signed out after logout"
  end

  test "current-session logout revokes a fallback device session that has no current refresh token" do
    user = clients(:one)
    headers = authenticated_headers_for(user, host: ENV.fetch("ID_SERVICE_URL"))
    token = ClientToken.find_by(public_id: headers["X-TEST-SESSION-PUBLIC-ID"])
    device_session = token.device_session

    # A fallback (non-DBSC) session legitimately has no current refresh token.
    # Sign-out must still revoke it.
    assert_not_nil device_session
    assert_nil device_session.current_refresh_token_id

    AuthenticationLogoutCurrentSession.call(
      resource: user,
      token_class: ClientToken,
      session_public_id: token.public_id,
      reason: "user_logout",
    )

    assert_predicate device_session.reload, :revoked?
    assert_predicate token.reload, :revoked?
  end
end
