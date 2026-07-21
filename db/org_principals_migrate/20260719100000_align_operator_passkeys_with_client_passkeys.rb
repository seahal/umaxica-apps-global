# frozen_string_literal: true

# Pre-deploy alignment of operator_passkeys with the client/visitor passkey
# shape: rename name -> description, unify external_id to uuid, drop the
# never-written user_handle/webauthn_id_binary/string-transports columns, and
# add the same display-only authenticator metadata columns.
class AlignOperatorPasskeysWithClientPasskeys < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      rename_column(:operator_passkeys, :name, :description)
      change_column_default(:operator_passkeys, :description, "")
      change_column(:operator_passkeys, :external_id, :uuid, using: "external_id::uuid")
      change_column(:operator_passkeys, :sign_count, :bigint)
      change_column_default(:operator_passkeys, :sign_count, 0)
      remove_column(:operator_passkeys, :user_handle, if_exists: true)
      remove_column(:operator_passkeys, :webauthn_id_binary, if_exists: true)
      remove_column(:operator_passkeys, :transports, if_exists: true)
    end

    add_column(:operator_passkeys, :aaguid, :uuid)
    add_column(:operator_passkeys, :transports, :jsonb)
    # Three-state on purpose: nil means "flag not captured at registration",
    # which is distinct from an authenticator reporting false.
    # rubocop:disable Rails/ThreeStateBooleanColumn
    add_column(:operator_passkeys, :backup_eligible, :boolean)
    add_column(:operator_passkeys, :backup_state, :boolean)
    # rubocop:enable Rails/ThreeStateBooleanColumn
    add_column(:operator_passkeys, :authenticator_attachment, :string)
    add_column(:operator_passkeys, :provider_name, :string)
    add_column(:operator_passkeys, :metadata_source, :string)
  end

  def down
    remove_column(:operator_passkeys, :metadata_source)
    remove_column(:operator_passkeys, :provider_name)
    remove_column(:operator_passkeys, :authenticator_attachment)
    remove_column(:operator_passkeys, :backup_state)
    remove_column(:operator_passkeys, :backup_eligible)
    remove_column(:operator_passkeys, :transports)
    remove_column(:operator_passkeys, :aaguid)

    safety_assured do
      add_column(:operator_passkeys, :transports, :string)
      add_column(:operator_passkeys, :user_handle, :string)
      change_column_default(:operator_passkeys, :sign_count, nil)
      change_column(:operator_passkeys, :sign_count, :integer)
      change_column(:operator_passkeys, :external_id, :string)
      change_column_default(:operator_passkeys, :description, nil)
      rename_column(:operator_passkeys, :description, :name)
    end
  end
end
