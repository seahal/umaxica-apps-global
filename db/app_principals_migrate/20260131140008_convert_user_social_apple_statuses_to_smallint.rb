# frozen_string_literal: true

class ConvertUserSocialAppleStatusesToSmallint < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      add_column(:user_social_apple_statuses, :id_small, :integer, limit: 2)

      execute("INSERT INTO user_social_apple_statuses (id) VALUES ('ACTIVE') ON CONFLICT DO NOTHING")
      execute("UPDATE user_social_apple_statuses SET id_small = 1 WHERE id = 'ACTIVE'")
      execute("UPDATE user_social_apple_statuses SET id_small = 0 WHERE id IN ('NEYO', '')")
      execute(<<~SQL.squish)
        WITH numbered AS (
          SELECT id, ROW_NUMBER() OVER (ORDER BY id) + 1 AS rn
          FROM user_social_apple_statuses
          WHERE id_small IS NULL
        )
        UPDATE user_social_apple_statuses SET id_small = numbered.rn
        FROM numbered WHERE user_social_apple_statuses.id = numbered.id
      SQL

      change_column_null(:user_social_apple_statuses, :id_small, false, 0)

      remove_index(:user_social_apple_statuses, name: "index_user_identity_apple_statuses_on_lower_id")
      execute("ALTER TABLE user_social_apple_statuses DROP CONSTRAINT IF EXISTS chk_user_identity_social_apple_statuses_id_format")
      drop_primary_key("user_social_apple_statuses")

      rename_column(:user_social_apple_statuses, :id, :id_old_string)

      rename_column(:user_social_apple_statuses, :id_small, :id)

      execute("ALTER TABLE user_social_apple_statuses ADD PRIMARY KEY (id)")
      add_check_constraint(:user_social_apple_statuses, "id >= 0", name: "user_social_apple_statuses_id_non_negative")

      add_column(:user_social_apples, :user_identity_social_apple_status_id_small, :integer, limit: 2, default: 1)
      execute(<<~SQL.squish)
        UPDATE user_social_apples a SET user_identity_social_apple_status_id_small = s.id
        FROM user_social_apple_statuses s WHERE a.user_identity_social_apple_status_id = s.id_old_string
      SQL

      remove_index(:user_social_apples, name: "idx_on_user_identity_social_apple_status_id_93441f369d")
      execute("ALTER TABLE user_social_apples DROP CONSTRAINT IF EXISTS chk_user_identity_social_apples_user_identity_social_apple_stat")
      remove_column(:user_social_apples, :user_identity_social_apple_status_id)
      rename_column(
        :user_social_apples, :user_identity_social_apple_status_id_small,
        :user_identity_social_apple_status_id,
      )
      change_column_null(:user_social_apples, :user_identity_social_apple_status_id, false)
      change_column_default(:user_social_apples, :user_identity_social_apple_status_id, from: 1, to: 1)

      add_foreign_key(:user_social_apples, :user_social_apple_statuses, column: :user_identity_social_apple_status_id)
      add_index(
        :user_social_apples, :user_identity_social_apple_status_id,
        name: "idx_on_user_identity_social_apple_status_id_93441f369d",
      )
      add_check_constraint(
        :user_social_apples, "user_identity_social_apple_status_id >= 0",
        name: "user_social_apples_user_identity_social_apple_status_id_non_negative",
      )

      remove_column(:user_social_apple_statuses, :id_old_string)
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
