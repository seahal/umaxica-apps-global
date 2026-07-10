# frozen_string_literal: true

class ConvertUserIdentityAuditEventsToSmallint < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      add_column(:user_identity_audit_events, :id_small, :integer, limit: 2)

      execute("UPDATE user_identity_audit_events SET id_small = 0 WHERE id::text IN ('NEYO', '')")
      execute(<<~SQL.squish)
        WITH numbered AS (
          SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn
          FROM user_identity_audit_events
          WHERE id_small IS NULL
        )
        UPDATE user_identity_audit_events SET id_small = numbered.rn
        FROM numbered WHERE user_identity_audit_events.id = numbered.id
      SQL

      change_column_null(:user_identity_audit_events, :id_small, false, 0)

      drop_primary_key("user_identity_audit_events")

      rename_column(:user_identity_audit_events, :id, :id_old_string)

      rename_column(:user_identity_audit_events, :id_small, :id)

      execute("ALTER TABLE user_identity_audit_events ADD PRIMARY KEY (id)")
      add_check_constraint(:user_identity_audit_events, "id >= 0", name: "user_identity_audit_events_id_non_negative")

      add_column(:user_identity_audits, :event_id_small, :integer, limit: 2, default: 0)
      execute(<<~SQL.squish)
        UPDATE user_identity_audits a SET event_id_small = e.id
        FROM user_identity_audit_events e WHERE a.event_id = e.id_old_string
      SQL

      remove_index(:user_identity_audits, name: "index_user_identity_audits_on_event_id")
      remove_column(:user_identity_audits, :event_id)
      rename_column(:user_identity_audits, :event_id_small, :event_id)
      change_column_null(:user_identity_audits, :event_id, false)
      change_column_default(:user_identity_audits, :event_id, from: 0, to: 0)

      add_foreign_key(:user_identity_audits, :user_identity_audit_events, column: :event_id)
      add_index(:user_identity_audits, :event_id)
      add_check_constraint(:user_identity_audits, "event_id >= 0", name: "user_identity_audits_event_id_non_negative")

      remove_column(:user_identity_audit_events, :id_old_string)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def drop_primary_key(table_name)
    constraint_name = select_value(<<~SQL.squish)
      SELECT constraint_name
      FROM information_schema.table_constraints
      WHERE table_schema = 'public'
        AND table_name = #{connection.quote(table_name)}
        AND constraint_type = 'PRIMARY KEY'
    SQL
    return unless constraint_name

    execute(<<~SQL.squish)
      ALTER TABLE #{connection.quote_table_name(table_name)}
      DROP CONSTRAINT #{connection.quote_column_name(constraint_name)} CASCADE
    SQL
  end
end
