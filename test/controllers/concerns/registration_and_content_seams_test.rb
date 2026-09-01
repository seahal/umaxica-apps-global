# typed: false
# frozen_string_literal: true

require "test_helper"

# Three delegations the shared flows go through so a surface can override them:
# how a passkey row is persisted, how the active authenticator list is scoped,
# and how published entries are serialised for the JSON contract.
class RegistrationAndContentSeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a passkey registration is persisted through the overridable save seam" do
    harness = Class.new { include PasskeyRegistrationFlow }.new
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    passkey = ClientPasskey.new(
      user: client,
      webauthn_id: Base64.urlsafe_encode64("seam-credential", padding: false),
      public_key: "public-key",
      sign_count: 0,
      description: "Seam",
    )

    assert_difference -> { ClientPasskey.count }, 1 do
      harness.send(:save_passkey_registration!, passkey)
    end
  end

  test "the app verification authenticator list is scoped to the active credentials of the signed-in client" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    active = ClientTotpCredential.create!(
      user: client,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      title: "active",
    )
    ClientTotpCredential.create!(
      user: client,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::REVOKED,
      title: "revoked",
    )

    harness = Class.new do
      include SignAppVerificationBase

      def initialize(client) = @client = client

      def current_client = @client
    end.new(client)

    assert_equal [active], harness.send(:active_totp_credentials).to_a
  end

  test "published entries are serialised one row at a time and unpublishable rows are dropped" do
    harness = Class.new(ActionController::Base) do
      include PublishingContentRendering

      attr_accessor :entries

      def publishing_entries_query = Struct.new(:rows) { def call = rows }.new(entries)

      def publishing_entry_json(entry) = (entry == :skip) ? nil : { slug: entry }
    end.new
    harness.entries = [:first, :skip, :second]

    assert_equal [{ slug: :first }, { slug: :second }], harness.send(:publishing_entries_json)
  end
end
