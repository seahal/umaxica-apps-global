# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationLinkUseCaseTest < ActiveSupport::TestCase
  fixtures :client_google_identity_statuses

  test "links a verified principal and returns a typed result" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "link_uc_#{SecureRandom.hex(4)}")
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: "link-use-case-subject",
      issuer: "https://accounts.google.com",
      audience: "google-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google-oauth2/contract",
    )

    result = ExternalAuthenticationLinkUseCase.call(
      principal: principal,
      credential_candidate: nil,
      user: client,
    )

    assert_instance_of ExternalAuthentication::LinkResult, result
    assert_equal :linked, result.status
    assert_equal client, result.user
    assert_equal "link-use-case-subject", result.identity.uid
    assert_equal client, result.identity.user
  end

  test "rejects link without an authenticated user" do
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: "link-use-case-no-user",
      issuer: "https://accounts.google.com",
      audience: "google-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google-oauth2/contract",
    )

    assert_raises(SocialAuth::UnauthorizedError) do
      ExternalAuthenticationLinkUseCase.call(
        principal: principal,
        credential_candidate: nil,
        user: nil,
      )
    end
  end
end
