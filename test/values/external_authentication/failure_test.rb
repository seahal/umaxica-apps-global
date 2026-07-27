# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationFailureTest < ActiveSupport::TestCase
  test "represents a provider-safe callback failure" do
    failure = ExternalAuthentication::Failure.new(
      code: :invalid_callback,
      provider: "apple",
      retryable: false,
      safe_reason: :assertion_invalid,
    )

    assert_equal :invalid_callback, failure.code
    assert_equal "apple", failure.provider
    assert_not failure.retryable
    assert_equal :assertion_invalid, failure.safe_reason
    assert_predicate failure, :frozen?
  end

  test "rejects unknown failure codes" do
    error =
      assert_raises(ArgumentError) do
        ExternalAuthentication::Failure.new(
          code: :raw_provider_error,
          provider: "google",
          retryable: false,
          safe_reason: :assertion_invalid,
        )
      end

    assert_equal "code is unsupported", error.message
  end

  test "rejects arbitrary provider reason text" do
    error =
      assert_raises(ArgumentError) do
        ExternalAuthentication::Failure.new(
          code: :invalid_callback,
          provider: "google",
          retryable: false,
          safe_reason: "provider response contained a token",
        )
      end

    assert_equal "safe_reason is unsupported", error.message
  end

  test "requires a strict boolean retry classification" do
    error =
      assert_raises(ArgumentError) do
        ExternalAuthentication::Failure.new(
          code: :provider_unavailable,
          provider: "google",
          retryable: "true",
          safe_reason: :provider_unavailable,
        )
      end

    assert_equal "retryable must be boolean", error.message
  end
end
