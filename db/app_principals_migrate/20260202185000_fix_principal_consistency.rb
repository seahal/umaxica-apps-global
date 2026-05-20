# frozen_string_literal: true

class FixPrincipalConsistency < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      enable_extension('citext') unless extension_enabled?('citext')

      # 1. User Identity Audits
      if table_exists?(:user_identity_audits)
        execute("TRUNCATE TABLE user_identity_audits CASCADE")

        # Events
        recreate_pk_table(:user_identity_audit_events)
        recreate_pk_table(:user_identity_audit_levels)

        # FK cols
        [:event_id, :level_id].each do |col|
          if column_exists?(:user_identity_audits, col)
            execute("ALTER TABLE user_identity_audits ALTER COLUMN #{col} TYPE bigint USING #{col}::bigint")
            execute("ALTER TABLE user_identity_audits ALTER COLUMN #{col} SET DEFAULT 0")
            execute("ALTER TABLE user_identity_audits ALTER COLUMN #{col} SET NOT NULL")

            status_table = (col == :event_id) ? :user_identity_audit_events : :user_identity_audit_levels

            add_fk_sql(:user_identity_audits, status_table, col)
          end
        end
      end

      # 2. Clients
      if table_exists?(:clients)
        # Drop status_id (smallint)
        if column_exists?(:clients, :status_id)
          execute("ALTER TABLE clients DROP COLUMN status_id")
        end

        # Ensure client_status_id (bigint) has FK
        if column_exists?(:clients, :client_status_id)
          add_fk_sql(:clients, :client_statuses, :client_status_id)
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def recreate_pk_table(table_name)
    return unless table_exists?(table_name)

    drop_table(table_name, force: :cascade)
    create_table(table_name) do |t|
      t.citext(:code, null: false)
      t.index(:code, unique: true)
    end
  end

  def add_fk_sql(from_table, to_table, column)
    fk_name = "fk_#{from_table}_on_#{column}"
    result = connection.select_value("SELECT 1 FROM pg_constraint WHERE conname = '#{fk_name}'")
    unless result
      execute("ALTER TABLE #{from_table} ADD CONSTRAINT #{fk_name} FOREIGN KEY (#{column}) REFERENCES #{to_table} (id)")
    end
  rescue => e
    Rails.logger.debug { "Error adding FK #{fk_name}: #{e.message}" }
  end
end
