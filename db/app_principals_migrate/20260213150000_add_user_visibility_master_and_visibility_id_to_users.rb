# frozen_string_literal: true

class AddUserVisibilityMasterAndVisibilityIdToUsers < ActiveRecord::Migration[8.2]
  def up
    create_table(:user_visibilities, id: :bigint)

    safety_assured do
      execute(<<~SQL.squish)
        INSERT INTO user_visibilities (id)
        VALUES (0), (1), (2), (3)
        ON CONFLICT DO NOTHING
      SQL

      execute(<<~SQL.squish)
        SELECT setval(pg_get_serial_sequence('user_visibilities', 'id'), 3, true)
      SQL
    end

    safety_assured do
      add_column(:users, :visibility_id, :bigint, null: false, default: 2)
      add_index(:users, :visibility_id)
      add_foreign_key(:users, :user_visibilities, column: :visibility_id)
    end
  end

  def down
    safety_assured do
      remove_foreign_key(:users, column: :visibility_id)
      remove_index(:users, :visibility_id)
      remove_column(:users, :visibility_id)
    end

    drop_table(:user_visibilities)
  end
end
