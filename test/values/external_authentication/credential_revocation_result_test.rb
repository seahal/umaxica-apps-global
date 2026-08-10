# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationCredentialRevocationResultTest < ActiveSupport::TestCase
  test "successful revocation has no code and is not retryable" do
    result = ExternalAuthentication::CredentialRevocationResult.new(status: :revoked_or_already_invalid)

    assert_predicate result, :successful?
    assert_nil result.code
    assert_not result.retryable?
    assert_predicate result, :frozen?
  end

  test "failed results require a code and expose retryability" do
    retryable = ExternalAuthentication::CredentialRevocationResult.new(status: :failed, code: :rate_limited)
    permanent = ExternalAuthentication::CredentialRevocationResult.new(status: :failed, code: :invalid_token)

    assert_not retryable.successful?
    assert_predicate retryable, :retryable?
    assert_equal :rate_limited, retryable.code

    assert_not permanent.successful?
    assert_not permanent.retryable?
    assert_equal :invalid_token, permanent.code
  end

  test "rejects invalid status and code combinations" do
    assert_raises(ArgumentError) do
      ExternalAuthentication::CredentialRevocationResult.new(status: :revoked_or_already_invalid, code: :rate_limited)
    end

    assert_raises(ArgumentError) do
      ExternalAuthentication::CredentialRevocationResult.new(status: :failed)
    end

    assert_raises(ArgumentError) do
      ExternalAuthentication::CredentialRevocationResult.new(status: :unknown)
    end
  end
end
