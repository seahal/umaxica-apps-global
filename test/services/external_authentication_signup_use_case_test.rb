# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/external_identity_test_helper"

class ExternalAuthenticationSignupUseCaseTest < ActiveSupport::TestCase
  include ExternalIdentityTestHelper

  test "creates an account and returns a typed signup result" do
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: "signup-use-case-subject",
      issuer: "https://accounts.google.com",
      audience: "google-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google-oauth2/contract",
    )

    result = nil
    assert_difference("Client.count", 1) do
      assert_difference("ClientExternalIdentity.count", 1) do
        result = ExternalAuthenticationSignupUseCase.call(
          principal: principal,
          credential_candidate: nil,
          birthdate: "2000-01-01",
        )
      end
    end

    assert_instance_of ExternalAuthentication::SignupResult, result
    assert_equal :created, result.status
    assert_equal "signup-use-case-subject", result.identity.uid
    assert_equal result.user, result.identity.user
  end

  test "rejects a subject already bound to an account" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "signup_uc_#{SecureRandom.hex(4)}")
    identity = create_active_external_identity(client: client, provider: "google", subject: "signup-use-case-conflict")
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: identity.subject,
      issuer: "https://accounts.google.com",
      audience: "google-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google-oauth2/contract",
    )

    assert_raises(SocialAuth::ProviderError) do
      ExternalAuthenticationSignupUseCase.call(
        principal: principal,
        credential_candidate: nil,
        birthdate: "2000-01-01",
      )
    end
  end
end
