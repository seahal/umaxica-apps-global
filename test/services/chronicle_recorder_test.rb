# typed: false
# frozen_string_literal: true

require "test_helper"

class ChronicleRecorderTest < ActiveSupport::TestCase
  test "sanitize removes forbidden keys from hash" do
    input = { "token" => "secret", "browser" => "Chrome", "password" => "hunter2" }
    result = ChronicleRecorder.sanitize(input)

    assert_includes result, "browser"
    assert_not_includes result, "token"
    assert_not_includes result, "password"
  end

  test "sanitize handles nested hashes" do
    input = { "nested" => { "token" => "secret", "ok" => "value" } }
    result = ChronicleRecorder.sanitize(input)

    assert_equal({ "ok" => "value" }, result["nested"])
  end

  test "sanitize filters arrays recursively" do
    input = [{ "token" => "secret" }, { "browser" => "Chrome" }]
    result = ChronicleRecorder.sanitize(input)

    assert_equal [{}, { "browser" => "Chrome" }], result
  end

  test "sanitize handles string values" do
    input = "Hello world"
    result = ChronicleRecorder.sanitize(input)

    assert_equal "Hello world", result
  end

  test "sanitize filters sensitive patterns in strings" do
    input = "Bearer eyJhbGciOiJIUzI1NiJ9.eyJkYXRhIjoiMSJ9.xXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXX"
    result = ChronicleRecorder.sanitize(input)

    assert_includes result, "[FILTERED]"
  end

  test "sanitize_text returns nil for nil input" do
    assert_nil ChronicleRecorder.sanitize_text(nil)
  end

  test "sanitize_text sanitizes string" do
    result = ChronicleRecorder.sanitize_text("Bearer token123")

    assert_includes result, "[FILTERED]"
  end

  test "retention_policy_code_for returns permanent for matching patterns" do
    assert_equal "permanent", ChronicleRecorder.retention_policy_code_for("audit.export.2024")
    assert_equal "permanent", ChronicleRecorder.retention_policy_code_for("record.deleted")
    assert_equal "permanent", ChronicleRecorder.retention_policy_code_for("record.destroyed")
    assert_equal "permanent", ChronicleRecorder.retention_policy_code_for("action.irreversible")
  end

  test "retention_policy_code_for returns security for rate_limit" do
    assert_equal "security", ChronicleRecorder.retention_policy_code_for("rate_limit.exceeded")
    assert_equal "security", ChronicleRecorder.retention_policy_code_for("csrf_detected")
  end

  test "retention_policy_code_for returns known action policies" do
    assert_equal "ephemeral", ChronicleRecorder.retention_policy_code_for("auth.sign_in.succeeded")
    assert_equal "ephemeral", ChronicleRecorder.retention_policy_code_for("auth.sign_out.succeeded")
    assert_equal "security", ChronicleRecorder.retention_policy_code_for("auth.sign_in.failed")
    assert_equal "compliance", ChronicleRecorder.retention_policy_code_for("auth.step_up.succeeded")
    assert_equal "compliance", ChronicleRecorder.retention_policy_code_for("auth.aal.changed")
    assert_equal "compliance", ChronicleRecorder.retention_policy_code_for("account.suspended")
    assert_equal "compliance", ChronicleRecorder.retention_policy_code_for("chronicle.audit_incomplete")
  end

  test "retention_policy_code_for defaults to security for unknown actions" do
    assert_equal "security", ChronicleRecorder.retention_policy_code_for("unknown.action")
  end

  test "actor_payload returns nil values for blank actor" do
    payload = ChronicleRecorder.actor_payload(nil)

    assert_nil payload[:actor_type]
    assert_nil payload[:actor_id]
  end

  test "actor_payload extracts actor info" do
    client = clients(:one)
    payload = ChronicleRecorder.actor_payload(client)

    assert_equal "Client", payload[:actor_type]
    assert_predicate payload[:actor_id], :present?
  end

  test "subject_payload extracts subject info" do
    visitor = visitors(:reserved_visitor)
    payload = ChronicleRecorder.subject_payload(visitor)

    assert_equal "Visitor", payload[:subject_type]
    assert_predicate payload[:subject_id], :present?
  end

  test "log_payload builds complete payload" do
    client = clients(:one)
    payload = ChronicleRecorder.log_payload(
      event: "test.event",
      event_uuid: "abc-123",
      request_id: "req-456",
      action: "test.action",
      actor: client,
      subject: client,
      error: nil,
    )

    assert_equal "test.event", payload[:event]
    assert_equal "abc-123", payload[:event_uuid]
    assert_equal "req-456", payload[:request_id]
    assert_equal "test.action", payload[:action]
    assert_equal "Client", payload[:actor_type]
    assert_equal "Client", payload[:subject_type]
  end

  test "log_payload includes error info" do
    error = RuntimeError.new("Something broke")
    client = clients(:one)
    payload = ChronicleRecorder.log_payload(
      event: "test.error",
      event_uuid: "abc-123",
      request_id: "req-456",
      action: "test.error",
      actor: client,
      subject: nil,
      error: error,
    )

    assert_equal "RuntimeError", payload[:error_class]
    assert_includes payload[:error_message], "Something broke"
  end

  test "sanitize preserves allowed digest keys" do
    input = { "session_id_digest" => "abc123", "token" => "secret" }
    result = ChronicleRecorder.sanitize(input)

    assert_includes result, "session_id_digest"
    assert_not_includes result, "token"
  end

  test "sanitize filters reserved context keys" do
    input = { "request_id" => "123", "ip_address" => "127.0.0.1", "user_agent" => "Chrome", "custom" => "ok" }
    result = ChronicleRecorder.sanitize(input)

    assert_not_includes result, "request_id"
    assert_not_includes result, "ip_address"
    assert_not_includes result, "user_agent"
    assert_includes result, "custom"
  end

  test "forbidden_key? detects sensitive keys" do
    assert ChronicleRecorder.send(:forbidden_key?, "password")
    assert ChronicleRecorder.send(:forbidden_key?, "PASSWORD")
    assert ChronicleRecorder.send(:forbidden_key?, "token_value")
    assert_not ChronicleRecorder.send(:forbidden_key?, "browser")
    assert_not ChronicleRecorder.send(:forbidden_key?, "session_id_digest")
  end

  test "sanitize_error_message truncates long messages" do
    long = "x" * 2000
    result = ChronicleRecorder.send(:sanitize_error_message, long)

    assert_operator result.bytesize, :<=, 1024
  end

  test "sanitize_error_message returns nil for blank" do
    assert_nil ChronicleRecorder.send(:sanitize_error_message, "")
    assert_nil ChronicleRecorder.send(:sanitize_error_message, nil)
  end

  test "sanitize_string filters all sensitive patterns" do
    jwt_part = "eyJhbGciOiJIUzI1NiJ9.eyJkYXRhIjoiMSJ9." \
               "xXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXX"
    input = "Bearer #{jwt_part} and password=secret123"
    result = ChronicleRecorder.send(:sanitize_string, input.dup)

    assert_includes result, "[FILTERED]"
    assert_not_includes result, "password=secret123"
  end
end
