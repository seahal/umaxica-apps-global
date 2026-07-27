# frozen_string_literal: true

class CreateClientAppleNotificationEvents < ActiveRecord::Migration[8.2]
  def up
    add_column(:client_external_identities, :last_provider_event_at, :datetime)

    create_table(:client_apple_notification_events) do |t|
      t.string(:jti, null: false)
      t.string(:event_type, limit: 32, null: false)
      t.references(:client_external_identity, foreign_key: false)
      t.datetime(:received_at, null: false)
      t.datetime(:occurred_at, null: false)
      t.string(:status, limit: 32, null: false, default: "received")
      t.integer(:processing_attempts, null: false, default: 0)
      t.datetime(:next_retry_at)
      t.datetime(:processed_at)
      t.datetime(:dead_lettered_at)
      t.string(:failure_code, null: false, default: "")
      t.timestamps

      t.index(:jti, unique: true)
      t.index(%i(status next_retry_at), name: "idx_client_apple_notification_events_retry")
      t.check_constraint(
        "event_type IN ('email-enabled', 'email-disabled', 'consent-revoked', 'account-deleted')",
        name: "chk_client_apple_notification_events_type",
      )
      t.check_constraint(
        "status IN ('received', 'retrying', 'completed', 'dead_letter')",
        name: "chk_client_apple_notification_events_status",
      )
      t.check_constraint("processing_attempts >= 0", name: "chk_client_apple_notification_events_attempts")
    end

    safety_assured { execute("ALTER TABLE client_apple_notification_events SET UNLOGGED") }
    add_foreign_key(
      :client_apple_notification_events,
      :client_external_identities,
      on_delete: :nullify,
      validate: false,
    )
  end

  def down
    remove_column(:client_external_identities, :last_provider_event_at) if
      column_exists?(:client_external_identities, :last_provider_event_at)
    drop_table(:client_apple_notification_events)
  end
end
