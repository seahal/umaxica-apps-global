# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class RedirectsTargetResultTest < ActiveSupport::TestCase
  test "ok creates a successful result" do
    result = RedirectsTargetResult.ok(kind: :internal, source: :none, value: "/dashboard")

    assert_predicate result, :ok?
    assert_equal :internal, result.kind
    assert_equal "/dashboard", result.value
    assert_nil result.failure_reason
    assert_nil result.unsafe_value_digest
  end

  test "failure creates a failed result" do
    result = RedirectsTargetResult.failure(kind: :internal, source: :none, reason: "Not found")

    assert_not_predicate result, :ok?
    assert_equal "Not found", result.failure_reason
    assert_nil result.value
  end

  test "failure with unsafe value computes digest" do
    result = RedirectsTargetResult.failure(
      kind: :external, source: :configured, reason: "Unsafe",
      unsafe_value: "https://evil.com",
    )

    assert_not_predicate result, :ok?
    assert_predicate result.unsafe_value_digest, :present?
  end

  test "failure with nil unsafe value has nil digest" do
    result = RedirectsTargetResult.failure(kind: :internal, source: :none, reason: "Error")

    assert_nil result.unsafe_value_digest
  end

  test "digest_unsafe_value returns nil for nil" do
    assert_nil RedirectsTargetResult.digest_unsafe_value(nil)
  end

  test "digest_unsafe_value computes SHA256" do
    digest = RedirectsTargetResult.digest_unsafe_value("test-value")

    assert_equal 64, digest.length
    assert_match(/\A[a-f0-9]+\z/, digest)
  end

  test "ok? returns false when value is nil" do
    result = RedirectsTargetResult.new(
      kind: :internal, source: :none, value: nil, failure_reason: nil,
      unsafe_value_digest: nil,
    )

    assert_not_predicate result, :ok?
  end

  test "data equality works" do
    result1 = RedirectsTargetResult.ok(kind: :internal, source: :none, value: "/path")
    result2 = RedirectsTargetResult.ok(kind: :internal, source: :none, value: "/path")

    assert_equal result1, result2
  end
end
