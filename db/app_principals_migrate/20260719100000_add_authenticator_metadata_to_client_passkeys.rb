# frozen_string_literal: true

# Display-only authenticator metadata captured at registration. aaguid is
# self-reported (attestation: "none") and must never feed security decisions;
# provider_name is the AAGUID-catalog friendly name, kept separate from the
# user-editable description so neither ever overwrites the other.
class AddAuthenticatorMetadataToClientPasskeys < ActiveRecord::Migration[8.2]
  def change
    add_column(:client_passkeys, :aaguid, :uuid)
    add_column(:client_passkeys, :transports, :jsonb)
    # Three-state on purpose: nil means "flag not captured at registration",
    # which is distinct from an authenticator reporting false.
    # rubocop:disable Rails/ThreeStateBooleanColumn
    add_column(:client_passkeys, :backup_eligible, :boolean)
    add_column(:client_passkeys, :backup_state, :boolean)
    # rubocop:enable Rails/ThreeStateBooleanColumn
    add_column(:client_passkeys, :authenticator_attachment, :string)
    add_column(:client_passkeys, :provider_name, :string)
    add_column(:client_passkeys, :metadata_source, :string)
  end
end
