# frozen_string_literal: true

class ConvertUserSecretKindsToSmallint < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      add_column(:user_secret_kinds, :id_small, :integer, limit: 2)

      %w(LOGIN TOTP RECOVERY API).each do |kind|
        execute("INSERT INTO user_secret_kinds (id) VALUES ('#{kind}') ON CONFLICT DO NOTHING")
      end

      mapping = { "LOGIN" => 1, "TOTP" => 2, "RECOVERY" => 3, "API" => 4 }
      mapping.each do |str, int|
        execute("UPDATE user_secret_kinds SET id_small = #{int} WHERE id = '#{str}'")
      end

      execute(<<~SQL.squish)
        WITH numbered AS (
          SELECT id, ROW_NUMBER() OVER (ORDER BY id) + 4 AS rn
          FROM user_secret_kinds
          WHERE id_small IS NULL
        )
        UPDATE user_secret_kinds SET id_small = numbered.rn
        FROM numbered WHERE user_secret_kinds.id = numbered.id
      SQL

      change_column_null(:user_secret_kinds, :id_small, false, 1)

      execute("ALTER TABLE user_secret_kinds DROP CONSTRAINT user_secret_kinds_pkey CASCADE")

      rename_column(:user_secret_kinds, :id, :id_old_string)

      rename_column(:user_secret_kinds, :id_small, :id)

      execute("ALTER TABLE user_secret_kinds ADD PRIMARY KEY (id)")
      add_check_constraint(:user_secret_kinds, "id >= 0", name: "user_secret_kinds_id_non_negative")

      add_column(:user_secrets, :user_secret_kind_id_small, :integer, limit: 2, default: 1)
      execute(<<~SQL.squish)
        UPDATE user_secrets s SET user_secret_kind_id_small = k.id
        FROM user_secret_kinds k WHERE s.user_secret_kind_id = k.id_old_string
      SQL

      remove_index(:user_secrets, name: "index_user_secrets_on_user_secret_kind_id")
      remove_column(:user_secrets, :user_secret_kind_id)
      rename_column(:user_secrets, :user_secret_kind_id_small, :user_secret_kind_id)
      change_column_null(:user_secrets, :user_secret_kind_id, false)
      change_column_default(:user_secrets, :user_secret_kind_id, from: 1, to: 1)

      add_foreign_key(:user_secrets, :user_secret_kinds, column: :user_secret_kind_id)
      add_index(:user_secrets, :user_secret_kind_id)
      add_check_constraint(
        :user_secrets, "user_secret_kind_id >= 0",
        name: "user_secrets_user_secret_kind_id_non_negative",
      )

      remove_column(:user_secret_kinds, :id_old_string)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
