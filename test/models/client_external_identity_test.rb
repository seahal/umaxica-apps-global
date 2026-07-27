# frozen_string_literal: true

require "test_helper"

class ClientExternalIdentityTest < ActiveSupport::TestCase
  fixtures :client_statuses

  test "deterministically encrypts a provider subject while preserving subject lookup" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "e#{SecureRandom.hex(8)}")
    identity = ClientExternalIdentity.create!(
      client: client,
      provider: "apple",
      issuer: "https://appleid.apple.com",
      subject: "apple-subject-1",
      audience: "apple-client-id",
      verification_authority: "omniauth-apple/1.4.0",
      verified_at: Time.utc(2026, 7, 24, 12, 0, 0),
    )

    stored_value = ClientExternalIdentity.connection.select_value(
      ClientExternalIdentity.where(id: identity.id).select(:subject).to_sql,
    )

    assert_not_includes stored_value, "apple-subject-1"
    assert_equal identity, ClientExternalIdentity.find_by!(
      issuer: "https://appleid.apple.com",
      subject: "apple-subject-1",
    )
    assert_predicate identity, :active?
  end

  test "allows one binding per provider for a client" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "e#{SecureRandom.hex(8)}")
    ClientExternalIdentity.create!(
      client: client,
      provider: "google",
      issuer: "https://accounts.google.com",
      subject: "google-subject-1",
      audience: "google-client-id",
      verification_authority: "omniauth-google-oauth2/1.2.1",
      verified_at: Time.current,
    )

    duplicate = ClientExternalIdentity.new(
      client: client,
      provider: "google",
      issuer: "https://accounts.google.com",
      subject: "google-subject-2",
      audience: "google-client-id",
      verification_authority: "omniauth-google-oauth2/1.2.1",
      verified_at: Time.current,
    )

    assert_not_predicate duplicate, :valid?
    assert duplicate.errors.of_kind?(:provider, :taken)
  end
end
