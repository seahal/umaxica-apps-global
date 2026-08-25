# typed: false
# frozen_string_literal: true

require "test_helper"

class SignAppSessionRevokeAuditTest < ActiveSupport::TestCase
  test "record! writes an audit event when sessions were revoked" do
    actor = Object.new
    calls = []

    IdentityAudit.stub(:record!, ->(**kwargs) { calls << kwargs }) do
      SignAppSessionRevokeAudit.record!(
        actor: actor,
        revoked_session_count: 3,
        action: "revoke_other_sessions",
        ip_address: "127.0.0.1",
        user_agent: "TestAgent",
      )
    end

    assert_equal 1, calls.size
    call = calls.first

    assert_equal actor, call[:actor]
    assert_equal ClientChronicleEvent::SESSION_REVOKED, call[:event_id]
    assert_equal "revoke_other_sessions", call[:action]
    assert_equal "127.0.0.1", call[:ip_address]
    assert_equal "TestAgent", call[:user_agent]
    assert_equal({ revoked_session_count: 3 }, call[:metadata])
  end

  test "record! is a no-op when no sessions were revoked" do
    calls = []

    IdentityAudit.stub(:record!, ->(**kwargs) { calls << kwargs }) do
      SignAppSessionRevokeAudit.record!(
        actor: Object.new,
        revoked_session_count: 0,
        action: "revoke_other_sessions",
        ip_address: "127.0.0.1",
        user_agent: "TestAgent",
      )
    end

    assert_empty calls
  end
end
