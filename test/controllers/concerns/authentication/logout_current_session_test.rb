# typed: false
# frozen_string_literal: true

require "test_helper"

class Authentication::LogoutCurrentSessionTest < ActiveSupport::TestCase
  fixtures :clients, :client_token_statuses, :client_token_kinds

  test "revokes current user session token by public id" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!

    Authentication::LogoutCurrentSession.call(
      resource: user,
      token_class: ClientToken,
      session_public_id: token.public_id,
      reason: "user_logout",
    )

    assert_predicate token.reload, :revoked?
    assert_not token.currently_usable?
  end

  test "revokes current user session token by oidc sid" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!

    Authentication::LogoutCurrentSession.call(
      resource: user,
      token_class: ClientToken,
      session_public_id: token.oidc_sid,
      reason: "user_logout",
    )

    assert_predicate token.reload, :revoked?
  end

  test "is idempotent when token is already revoked" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.revoke!

    assert_nothing_raised do
      Authentication::LogoutCurrentSession.call(
        resource: user,
        token_class: ClientToken,
        session_public_id: token.public_id,
        reason: "user_logout",
      )
    end

    assert_predicate token.reload, :revoked?
  end

  test "succeeds when token and session are nil" do
    assert_nothing_raised do
      Authentication::LogoutCurrentSession.call(
        resource: clients(:one),
        token_class: ClientToken,
        session_public_id: nil,
        reason: "user_logout",
      )
    end
  end
end
