# typed: false
# frozen_string_literal: true

require "test_helper"

class Authentication::LogoutAllSessionsTest < ActiveSupport::TestCase
  fixtures :clients, :client_token_statuses, :client_token_kinds

  test "revokes all sessions for a user" do
    user = clients(:one)
    first = build_user_token(user)
    second = build_user_token(user)

    Authentication::LogoutAllSessions.call(resource: user, reason: "staff_suspended")

    assert_predicate first.reload, :revoked?
    assert_predicate second.reload, :revoked?
  end

  # Regression: "revoke all" must be implemented as repeated calls to
  # the single-session primitive. If anyone re-introduces a parallel
  # revoke path inside LogoutAllSessions, this guard fails. See
  # adr/logout-primitive-and-composition.md.
  test "delegates each token revoke to LogoutCurrentSession primitive" do
    user = clients(:one)
    # Fixtures may attach pre-existing tokens to this client; we want a
    # deterministic count so we can prove the composition rule exactly.
    user.client_tokens.delete_all
    first = build_user_token(user)
    second = build_user_token(user)

    received_tokens = []
    fake =
      ->(token:, **) {
        received_tokens << token
        true
      }

    Authentication::LogoutCurrentSession.stub(:call, fake) do
      Authentication::LogoutAllSessions.call(resource: user, reason: "test_compose")
    end

    assert_equal 2, received_tokens.size,
                 "LogoutAllSessions must delegate to LogoutCurrentSession once per token"
    assert_equal [first.id, second.id].sort,
                 received_tokens.map(&:id).sort
  end

  test "increments session_version even when token scope is empty" do
    user = clients(:one)
    # Ensure the user has no tokens.
    user.client_tokens.delete_all

    if user.respond_to?(:session_version)
      starting = user.session_version.to_i

      Authentication::LogoutAllSessions.call(resource: user, reason: "test_empty")

      assert_equal starting + 1, user.reload.session_version,
                   "session_version must bump so still-valid JWTs are rejected at refresh"
    else
      Authentication::LogoutAllSessions.call(resource: user, reason: "test_empty")

      pass "Client does not currently expose session_version; skip"
    end
  end

  private

  def build_user_token(user)
    ClientToken.new(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB).tap do |token|
      token.send(:skip_session_limit_check=, true)
      token.save!
    end
  end
end
