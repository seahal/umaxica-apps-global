# frozen_string_literal: true

class ConvertUserStatusesToSmallint < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      add_column(:user_statuses, :id_small, :integer, limit: 2)

      execute("UPDATE user_statuses SET id_small = 1 WHERE id = 'NONE'")
      execute("UPDATE user_statuses SET id_small = 0 WHERE id = 'NEYO'")
      execute(<<~SQL.squish)
        WITH numbered AS (
          SELECT id, ROW_NUMBER() OVER (ORDER BY id) + 1 AS rn
          FROM user_statuses WHERE id_small IS NULL
        )
        UPDATE user_statuses SET id_small = numbered.rn
        FROM numbered WHERE user_statuses.id = numbered.id
      SQL

      change_column_null(:user_statuses, :id_small, false, 0)

      remove_index(:user_statuses, name: "index_user_identity_statuses_on_lower_id")
      execute("ALTER TABLE user_statuses DROP CONSTRAINT IF EXISTS chk_user_identity_statuses_id_format")
      drop_primary_key("user_statuses")

      rename_column(:user_statuses, :id, :id_old_string)

      rename_column(:user_statuses, :id_small, :id)

      execute("ALTER TABLE user_statuses ADD PRIMARY KEY (id)")
      add_check_constraint(:user_statuses, "id >= 0", name: "user_statuses_id_non_negative")

      add_column(:users, :status_id_small, :integer, limit: 2, default: 1)
      execute(<<~SQL.squish)
        UPDATE users u SET status_id_small = s.id
        FROM user_statuses s WHERE u.status_id = s.id_old_string
      SQL

      remove_index(:users, name: "index_users_on_status_id")
      execute("ALTER TABLE users DROP CONSTRAINT IF EXISTS chk_users_user_identity_status_id_format")
      remove_column(:users, :status_id)
      rename_column(:users, :status_id_small, :status_id)
      change_column_null(:users, :status_id, false)
      change_column_default(:users, :status_id, from: 1, to: 1)

      add_foreign_key(:users, :user_statuses, column: :status_id)
      add_index(:users, :status_id)
      add_check_constraint(:users, "status_id >= 0", name: "users_status_id_non_negative")

      remove_column(:user_statuses, :id_old_string)
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
