# frozen_string_literal: true

class ConvertClientStatusesToSmallint < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      add_column(:client_statuses, :id_small, :integer, limit: 2)

      execute("UPDATE client_statuses SET id_small = 0 WHERE id IN ('NEYO', '')")
      execute(<<~SQL.squish)
        WITH numbered AS (
          SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn
          FROM client_statuses
          WHERE id_small IS NULL
        )
        UPDATE client_statuses SET id_small = numbered.rn
        FROM numbered WHERE client_statuses.id = numbered.id
      SQL

      change_column_null(:client_statuses, :id_small, false, 0)

      remove_index(:client_statuses, name: "index_client_identity_statuses_on_lower_id")
      drop_primary_key("client_statuses")

      rename_column(:client_statuses, :id, :id_old_string)

      rename_column(:client_statuses, :id_small, :id)

      execute("ALTER TABLE client_statuses ADD PRIMARY KEY (id)")
      add_check_constraint(:client_statuses, "id >= 0", name: "client_statuses_id_non_negative")

      add_column(:clients, :status_id_small, :integer, limit: 2, default: 0)
      execute(<<~SQL.squish)
        UPDATE clients c SET status_id_small = s.id
        FROM client_statuses s WHERE c.status_id = s.id_old_string
      SQL

      remove_index(:clients, name: "index_clients_on_status_id")
      remove_column(:clients, :status_id)
      rename_column(:clients, :status_id_small, :status_id)
      change_column_null(:clients, :status_id, false)
      change_column_default(:clients, :status_id, from: 0, to: 0)

      add_foreign_key(:clients, :client_statuses, column: :status_id)
      add_index(:clients, :status_id)
      add_check_constraint(:clients, "status_id >= 0", name: "clients_status_id_non_negative")

      remove_column(:client_statuses, :id_old_string)
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
