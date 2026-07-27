# frozen_string_literal: true

class CreateClientAppleCredentialRevocations < ActiveRecord::Migration[8.2]
  def up
    create_table(:client_apple_credential_revocations) do |t|
      t.string(:public_id, limit: 21, null: false)
      t.references(:client, null: false, foreign_key: false)
      t.string(:refresh_token, null: false, default: "")
      t.string(:reason, null: false)
      t.string(:status, null: false, default: "pending")
      t.string(:last_failure_code, null: false, default: "")
      t.integer(:retry_count, null: false, default: 0)
      t.datetime(:requested_at, null: false)
      t.datetime(:completed_at)
      t.datetime(:next_retry_at)
      t.datetime(:retention_deadline_at, null: false)
      t.timestamps

      t.index(:public_id, unique: true)
      t.index(%i(status next_retry_at), name: "idx_client_apple_credential_revocations_retry")
      t.check_constraint(
        "status IN ('pending', 'retrying', 'completed', 'expired')",
        name: "chk_client_apple_credential_revocations_status",
      )
      t.check_constraint("retry_count >= 0", name: "chk_client_apple_credential_revocations_retry_count")
    end

    safety_assured { execute("ALTER TABLE client_apple_credential_revocations SET UNLOGGED") }
    add_foreign_key(:client_apple_credential_revocations, :clients, validate: false)
  end

  def down
    drop_table(:client_apple_credential_revocations)
  end
end
