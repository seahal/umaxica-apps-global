# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationVerifiedPrincipalTest < ActiveSupport::TestCase
  test "represents the minimal verified provider identity" do
    verified_at = Time.zone.local(2026, 7, 24, 12, 0, 0)

    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "apple",
      subject: "provider-subject",
      issuer: "https://appleid.apple.com",
      audience: "configured-client-id",
      verified_at: verified_at,
      verification_authority: "omniauth-apple/1.4.0",
    )

    assert_equal "apple", principal.provider
    assert_equal "provider-subject", principal.subject
    assert_equal "https://appleid.apple.com", principal.issuer
    assert_equal "configured-client-id", principal.audience
    assert_equal verified_at, principal.verified_at
    assert_equal "omniauth-apple/1.4.0", principal.verification_authority
    assert_predicate principal, :frozen?
  end

  test "rejects unsupported providers" do
    error =
      assert_raises(ArgumentError) do
        ExternalAuthentication::VerifiedPrincipal.new(
          provider: "email",
          subject: "provider-subject",
          issuer: "https://issuer.example",
          audience: "configured-client-id",
          verified_at: Time.zone.local(2026, 7, 24, 12, 0, 0),
          verification_authority: "contract-authority",
        )
      end

    assert_equal "provider is unsupported", error.message
  end

  test "rejects blank identity coordinates" do
    error =
      assert_raises(ArgumentError) do
        ExternalAuthentication::VerifiedPrincipal.new(
          provider: "google",
          subject: "",
          issuer: "https://accounts.google.com",
          audience: "configured-client-id",
          verified_at: Time.zone.local(2026, 7, 24, 12, 0, 0),
          verification_authority: "omniauth-google-oauth2/1.2.2",
        )
      end

    assert_equal "subject is required", error.message
  end

  test "rejects invalid verification time" do
    error =
      assert_raises(ArgumentError) do
        ExternalAuthentication::VerifiedPrincipal.new(
          provider: "google",
          subject: "provider-subject",
          issuer: "https://accounts.google.com",
          audience: "configured-client-id",
          verified_at: "2026-07-24T12:00:00Z",
          verification_authority: "omniauth-google-oauth2/1.2.2",
        )
      end

    assert_equal "verified_at must be a time", error.message
  end

  test "does not accept assertion or token fields" do
    assert_raises(ArgumentError) do
      ExternalAuthentication::VerifiedPrincipal.new(
        provider: "apple",
        subject: "provider-subject",
        issuer: "https://appleid.apple.com",
        audience: "configured-client-id",
        verified_at: Time.zone.local(2026, 7, 24, 12, 0, 0),
        verification_authority: "omniauth-apple/1.4.0",
        assertion_digest: "forbidden",
      )
    end
  end
end
