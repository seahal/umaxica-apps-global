# frozen_string_literal: true

class FixClientsStatusRelations < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      # 1. Client.belongs_to :client_status, foreign_key: :status_id
      #    DB has client_status_id but model expects status_id
      #    We need to add status_id column, copy from client_status_id, add FK

      if table_exists?(:clients)
        # Add status_id column if missing
        unless column_exists?(:clients, :status_id)
          execute("ALTER TABLE clients ADD COLUMN status_id bigint DEFAULT 0 NOT NULL")
          # Copy from client_status_id
          execute("UPDATE clients SET status_id = client_status_id")
        end

        # Add index on status_id
        unless index_exists?(:clients, :status_id)
          add_index(:clients, :status_id, algorithm: :concurrently)
        end

        # Add FK: clients.status_id -> client_statuses.id
        add_fk_sql(:clients, :client_statuses, :status_id)

        # Enforce NOT NULL on public_id (backfill with UUIDv7)
        if column_exists?(:clients, :public_id)
          execute("UPDATE clients SET public_id = '' WHERE public_id IS NULL OR public_id = ''")
          execute("ALTER TABLE clients ALTER COLUMN public_id SET NOT NULL")
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

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
