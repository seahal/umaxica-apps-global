# frozen_string_literal: true

class ConvertUserOneTimePasswordStatusesToSmallint < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      add_column(:user_one_time_password_statuses, :id_small, :integer, limit: 2)

      execute("INSERT INTO user_one_time_password_statuses (id) VALUES ('ACTIVE') ON CONFLICT DO NOTHING")
      execute("UPDATE user_one_time_password_statuses SET id_small = 1 WHERE id = 'ACTIVE'")
      execute("UPDATE user_one_time_password_statuses SET id_small = 0 WHERE id IN ('NEYO', '')")
      execute(<<~SQL.squish)
        WITH numbered AS (
          SELECT id, ROW_NUMBER() OVER (ORDER BY id) + 1 AS rn
          FROM user_one_time_password_statuses
          WHERE id_small IS NULL
        )
        UPDATE user_one_time_password_statuses SET id_small = numbered.rn
        FROM numbered WHERE user_one_time_password_statuses.id = numbered.id
      SQL

      change_column_null(:user_one_time_password_statuses, :id_small, false, 0)

      remove_index(:user_one_time_password_statuses, name: "index_user_identity_otp_statuses_on_lower_id")
      execute("ALTER TABLE user_one_time_password_statuses DROP CONSTRAINT IF EXISTS chk_user_identity_one_time_password_statuses_id_format")
      drop_primary_key("user_one_time_password_statuses")

      rename_column(:user_one_time_password_statuses, :id, :id_old_string)

      rename_column(:user_one_time_password_statuses, :id_small, :id)

      execute("ALTER TABLE user_one_time_password_statuses ADD PRIMARY KEY (id)")
      add_check_constraint(
        :user_one_time_password_statuses, "id >= 0",
        name: "user_one_time_password_statuses_id_non_negative",
      )

      add_column(
        :user_one_time_passwords, :user_identity_one_time_password_status_id_small, :integer, limit: 2,
                                                                                              default: 1,
      )
      execute(<<~SQL.squish)
        UPDATE user_one_time_passwords p SET user_identity_one_time_password_status_id_small = s.id
        FROM user_one_time_password_statuses s WHERE p.user_identity_one_time_password_status_id = s.id_old_string
      SQL

      remove_index(:user_one_time_passwords, name: "idx_on_user_identity_one_time_password_status_id_c03cdf0b39")
      execute("ALTER TABLE user_one_time_passwords DROP CONSTRAINT IF EXISTS chk_user_identity_one_time_passwords_user_identity_one_time_pas")
      remove_column(:user_one_time_passwords, :user_identity_one_time_password_status_id)
      rename_column(
        :user_one_time_passwords, :user_identity_one_time_password_status_id_small,
        :user_identity_one_time_password_status_id,
      )
      change_column_null(:user_one_time_passwords, :user_identity_one_time_password_status_id, false)
      change_column_default(:user_one_time_passwords, :user_identity_one_time_password_status_id, from: 1, to: 1)

      add_foreign_key(
        :user_one_time_passwords, :user_one_time_password_statuses,
        column: :user_identity_one_time_password_status_id,
      )
      add_index(
        :user_one_time_passwords, :user_identity_one_time_password_status_id,
        name: "idx_on_user_identity_one_time_password_status_id_c03cdf0b39",
      )
      add_check_constraint(
        :user_one_time_passwords, "user_identity_one_time_password_status_id >= 0",
        name: "user_one_time_passwords_user_identity_one_time_password_status_id_non_negative",
      )

      remove_column(:user_one_time_password_statuses, :id_old_string)
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
