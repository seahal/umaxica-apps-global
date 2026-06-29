# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SocialAuthVerifiedProviderAssertionTest < ActiveSupport::TestCase
  FRESH_IAT = -> { Time.current.to_i }

  def base_auth_hash(provider: "google", email_verified: nil, nonce: nil)
    {
      "provider" => provider,
      "uid" => "uid-12345",
      "credentials" => {
        "token" => "tok_abc",
        "expires_at" => (1.hour.from_now).to_i,
      },
      "extra" => {
        "raw_info" => {
          "iat" => FRESH_IAT.call,
          "email_verified" => email_verified,
          "nonce" => nonce,
        }.compact,
      },
    }
  end

  test "valid auth hash with email_verified true passes assertion" do
    auth = base_auth_hash(email_verified: true)
    result = SocialAuthVerifiedProviderAssertion.call(auth_hash: auth, expected_provider: "google")

    assert_equal auth, result
  end

  test "valid auth hash without email_verified claim passes assertion" do
    auth = base_auth_hash(email_verified: nil)
    result = SocialAuthVerifiedProviderAssertion.call(auth_hash: auth, expected_provider: "google")

    assert_equal auth, result
  end

  # Regression guard for FINDING-03: an explicitly unverified email must be rejected
  # even though the identity key is uid+provider (not email), to prevent future
  # code paths that match by email from creating an account-takeover vector.
  test "auth hash with email_verified false raises ProviderError" do
    auth = base_auth_hash(email_verified: false)
    assert_raises(SocialAuth::ProviderError) do
      SocialAuthVerifiedProviderAssertion.call(auth_hash: auth, expected_provider: "google")
    end
  end

  test "auth hash with email_verified string false raises ProviderError" do
    auth = base_auth_hash
    auth["extra"]["raw_info"]["email_verified"] = "false"
    assert_raises(SocialAuth::ProviderError) do
      SocialAuthVerifiedProviderAssertion.call(auth_hash: auth, expected_provider: "google")
    end
  end

  test "mismatched provider raises ProviderError" do
    auth = base_auth_hash(email_verified: true)
    assert_raises(SocialAuth::ProviderError) do
      SocialAuthVerifiedProviderAssertion.call(auth_hash: auth, expected_provider: "apple")
    end
  end

  test "missing uid raises ProviderError" do
    auth = base_auth_hash(email_verified: true)
    auth["uid"] = ""
    assert_raises(SocialAuth::ProviderError) do
      SocialAuthVerifiedProviderAssertion.call(auth_hash: auth, expected_provider: "google")
    end
  end

  test "expired credentials raise ProviderError" do
    auth = base_auth_hash(email_verified: true)
    auth["credentials"]["expires_at"] = (1.minute.ago).to_i
    assert_raises(SocialAuth::ProviderError) do
      SocialAuthVerifiedProviderAssertion.call(auth_hash: auth, expected_provider: "google")
    end
  end

  test "stale iat claim raises ProviderError" do
    auth = base_auth_hash(email_verified: true)
    auth["extra"]["raw_info"]["iat"] = (20.minutes.ago).to_i
    assert_raises(SocialAuth::ProviderError) do
      SocialAuthVerifiedProviderAssertion.call(auth_hash: auth, expected_provider: "google")
    end
  end

  test "nonce mismatch raises ProviderError when expected nonce is present" do
    auth = base_auth_hash(email_verified: true, nonce: "provider-nonce")
    assert_raises(SocialAuth::ProviderError) do
      SocialAuthVerifiedProviderAssertion.call(
        auth_hash: auth,
        expected_provider: "google",
        expected_nonce: "different-nonce",
      )
    end
  end

  test "matching nonce passes assertion when expected nonce is present" do
    auth = base_auth_hash(email_verified: true, nonce: "provider-nonce")
    result = SocialAuthVerifiedProviderAssertion.call(
      auth_hash: auth,
      expected_provider: "google",
      expected_nonce: "provider-nonce",
    )

    assert_equal auth, result
  end
end
