# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationCallbackResultTest < ActiveSupport::TestCase
  test "verified result carries only a verified principal and provider credential candidate" do
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "apple",
      subject: "provider-subject",
      issuer: "https://appleid.apple.com",
      audience: "configured-client-id",
      verified_at: Time.zone.local(2026, 7, 24, 12, 0, 0),
      verification_authority: "omniauth-apple/1.4.0",
    )
    credential_candidate = Data.define(:refresh_token).new(refresh_token: "callback-only-value")

    result = ExternalAuthentication::CallbackResult.verified(
      principal: principal,
      credential_candidate: credential_candidate,
    )

    assert_predicate result, :verified?
    assert_not result.failed?
    assert_equal principal, result.principal
    assert_equal credential_candidate, result.credential_candidate
    assert_nil result.failure
  end

  test "failed result carries only a typed failure" do
    failure = ExternalAuthentication::Failure.new(
      code: :provider_unavailable,
      provider: "google",
      retryable: true,
      safe_reason: :provider_unavailable,
    )

    result = ExternalAuthentication::CallbackResult.failed(failure: failure)

    assert_predicate result, :failed?
    assert_not result.verified?
    assert_equal failure, result.failure
    assert_nil result.principal
    assert_nil result.credential_candidate
  end

  test "rejects an unverified principal" do
    error =
      assert_raises(ArgumentError) do
        ExternalAuthentication::CallbackResult.verified(
          principal: { provider: "apple", subject: "untrusted" },
          credential_candidate: nil,
        )
      end

    assert_equal "verified result requires a principal and no failure", error.message
  end

  test "rejects invalid direct result combinations" do
    failure = ExternalAuthentication::Failure.new(
      code: :invalid_callback,
      provider: "apple",
      retryable: false,
      safe_reason: :assertion_invalid,
    )

    error =
      assert_raises(ArgumentError) do
        ExternalAuthentication::CallbackResult.new(
          status: :verified,
          principal: nil,
          credential_candidate: nil,
          failure: failure,
        )
      end

    assert_equal "verified result requires a principal and no failure", error.message
  end
end
