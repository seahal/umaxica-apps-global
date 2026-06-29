# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class AuthenticationLogoutCurrentSessionTest < ActiveSupport::TestCase
  fixtures :clients, :client_token_statuses, :client_token_kinds

  test "revokes current user session token by public id" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!

    assert_difference -> { ClientSignOutFlow.count }, 1 do
      AuthenticationLogoutCurrentSession.call(
        resource: user,
        token_class: ClientToken,
        session_public_id: token.public_id,
        reason: "user_logout",
      )
    end

    assert_predicate token.reload, :revoked?
    assert_not token.currently_usable?
    cycle = ClientSignOutFlow.recent_first.find_by!(token: token)

    assert_predicate cycle, :sign_out_completed?
    assert_equal ClientSignOutFlow.kind_id_for("IDP_SIGN_OUT"), cycle.kind_id
    assert_equal user.id, cycle.principal_id
    assert_equal token.refresh_token_family_id, cycle.refresh_token_family_id
    assert_not_nil cycle.access_discarded_at
    assert_not_nil cycle.logically_revoked_at
    assert_not_nil cycle.completed_at
  end

  test "revokes current user session token by oidc sid" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.rotate_refresh_token!

    AuthenticationLogoutCurrentSession.call(
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

    assert_difference -> { ClientSignOutFlow.count }, 1 do
      AuthenticationLogoutCurrentSession.call(
        resource: user,
        token_class: ClientToken,
        session_public_id: token.public_id,
        reason: "user_logout",
      )
    end

    assert_predicate token.reload, :revoked?
    assert_predicate ClientSignOutFlow.recent_first.find_by!(token: token), :sign_out_completed?
  end

  test "succeeds when token and session are nil" do
    assert_no_difference -> { ClientSignOutFlow.count } do
      AuthenticationLogoutCurrentSession.call(
        resource: clients(:one),
        token_class: ClientToken,
        session_public_id: nil,
        reason: "user_logout",
      )
    end
  end

  test "records visitor and operator sign-out cycles on their own surfaces" do
    visitor = Visitor.create!(public_id: "v#{SecureRandom.hex(10)}", status_id: VisitorStatus::ACTIVE)
    visitor_token = VisitorToken.create!(visitor: visitor)
    visitor_token.rotate_refresh_token!
    operator = Operator.create!(status_id: OperatorStatus::ACTIVE)
    operator_token = OperatorToken.create!(staff: operator)
    operator_token.rotate_refresh_token!

    assert_difference -> { VisitorSignOutFlow.count }, 1 do
      AuthenticationLogoutCurrentSession.call(
        resource: visitor,
        token_class: VisitorToken,
        session_public_id: visitor_token.public_id,
        reason: "visitor_logout",
      )
    end
    assert_difference -> { OperatorSignOutFlow.count }, 1 do
      AuthenticationLogoutCurrentSession.call(
        resource: operator,
        token_class: OperatorToken,
        session_public_id: operator_token.public_id,
        reason: "operator_logout",
      )
    end

    assert_predicate VisitorSignOutFlow.recent_first.find_by!(token: visitor_token), :sign_out_completed?
    assert_predicate OperatorSignOutFlow.recent_first.find_by!(token: operator_token), :sign_out_completed?
  end
end
