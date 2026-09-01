# typed: false
# frozen_string_literal: true

require "test_helper"

# Revoking every session of an account must reach that account's own token table
# -- reading the wrong one would report success while leaving the sessions
# live -- and one token that fails to revoke must not abandon the rest of the
# batch, so the failure is recorded and the sweep continues.
class AuthenticationLogoutAllSessionsScopeTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "each principal kind is swept through its own token table" do
    operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)

    assert_equal OperatorToken, AuthenticationLogoutAllSessions.new(operator: operator).send(:token_scope).klass
    assert_equal VisitorToken, AuthenticationLogoutAllSessions.new(visitor: visitor).send(:token_scope).klass
    assert_equal ClientToken, AuthenticationLogoutAllSessions.new(user: client).send(:token_scope).klass
  end

  test "a token that fails to revoke is recorded under the batch event and does not stop the sweep" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    token = ClientToken.create!(user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    sweep = AuthenticationLogoutAllSessions.new(user: client)
    recorded = []

    exploding = ->(**) { raise ActiveRecord::ConnectionNotEstablished, "writer unavailable" }

    Rails.logger.stub(:info, ->(*args, &block) { recorded << (args.first || block&.call).to_s }) do
      AuthenticationLogoutCurrentSession.stub(:call, exploding) do
        assert sweep.send(:revoke_one!, token)
      end
    end

    assert(recorded.any? { |line| line.include?("auth.logout_all_sessions.token_failed") })
  end
end
