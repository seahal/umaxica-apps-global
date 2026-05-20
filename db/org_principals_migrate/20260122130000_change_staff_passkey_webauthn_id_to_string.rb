# frozen_string_literal: true

# Change StaffPasskey webauthn_id from binary to string for consistency with UserPasskey.
# WebAuthn credential IDs are Base64URL-encoded strings, so string type is more appropriate.
require "base64"

class ChangeStaffPasskeyWebauthnIdToString < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  class StaffPasskey < ActiveRecord::Base
    self.table_name = "staff_passkeys"
  end

  TEMP_INDEX = "index_staff_identity_passkeys_on_webauthn_id_string"
  LEGACY_INDEX = "index_staff_identity_passkeys_on_webauthn_id"
  NOT_NULL_CONSTRAINT = "staff_passkeys_webauthn_id_not_null"

  def up
    add_column(:staff_passkeys, :webauthn_id_string, :string)

    backfill_webauthn_id_string
    change_column_default(:staff_passkeys, :webauthn_id_string, "")
    add_index(:staff_passkeys, :webauthn_id_string, unique: true, name: TEMP_INDEX, algorithm: :concurrently)

    if index_name_exists?(:staff_passkeys, LEGACY_INDEX)
      remove_index(:staff_passkeys, name: LEGACY_INDEX)
    end

    safety_assured do
      rename_column(:staff_passkeys, :webauthn_id, :webauthn_id_binary)
      rename_column(:staff_passkeys, :webauthn_id_string, :webauthn_id)
    end

    change_column_default(:staff_passkeys, :webauthn_id, "")
    add_check_constraint(:staff_passkeys, "webauthn_id IS NOT NULL", name: NOT_NULL_CONSTRAINT, validate: false)

    remove_index(:staff_passkeys, name: TEMP_INDEX, algorithm: :concurrently)
    add_index(:staff_passkeys, :webauthn_id, unique: true, name: LEGACY_INDEX, algorithm: :concurrently)

    safety_assured do
      remove_column(:staff_passkeys, :webauthn_id_binary)
    end

    add_external_id_if_missing
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def backfill_webauthn_id_string
    StaffPasskey.reset_column_information
    StaffPasskey.in_batches(of: 500) do |batch|
      batch.each do |passkey|
        raw_id = passkey[:webauthn_id]
        next if raw_id.blank?

        encoded = Base64.urlsafe_encode64(raw_id, padding: false)
        passkey.update!(webauthn_id_string: encoded)
      end
    end
  end

  def add_external_id_if_missing
    return if column_exists?(:staff_passkeys, :external_id)

    add_column(:staff_passkeys, :external_id, :bigint)
    StaffPasskey.reset_column_information
    StaffPasskey.find_each do |passkey|
      passkey.update!(external_id: SecureRandom.uuid)
    end
    change_column_null(:staff_passkeys, :external_id, false)
  end
end
