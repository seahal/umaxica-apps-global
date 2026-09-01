# typed: false
# frozen_string_literal: true

require "test_helper"

# When a device-bound refresh fails, the session behind it is revoked. A token
# that belongs to a device session revokes the whole device session; a token
# that does not is revoked on its own. A storage failure while doing so is
# recorded rather than raised, because the refusal itself must still be answered.
class AuthenticationBaseDbscRevocationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    include AuthenticationBase

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
    @client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
  end

  test "a token with no device session behind it is revoked on its own" do
    token = ClientToken.create!(user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    @harness.invoke(:revoke_refresh_session_after_dbsc_failure!, token)

    assert_predicate token.reload, :revoked?
  end

  test "a token that is already revoked is left alone" do
    token = ClientToken.create!(user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    token.revoke!
    revoked_at = token.reload.updated_at

    @harness.invoke(:revoke_refresh_session_after_dbsc_failure!, token)

    assert_equal revoked_at, token.reload.updated_at
  end

  test "no token at all is a no-op rather than a failure" do
    assert_nil @harness.invoke(:revoke_refresh_session_after_dbsc_failure!, nil)
  end
end
