# frozen_string_literal: true

class AddStaffVisibilityMasterAndVisibilityIdToStaffs < ActiveRecord::Migration[8.2]
  def up
    create_table(:staff_visibilities, id: :bigint)

    safety_assured do
      execute(<<~SQL.squish)
        INSERT INTO staff_visibilities (id)
        VALUES (0), (1), (2), (3)
        ON CONFLICT DO NOTHING
      SQL

      execute(<<~SQL.squish)
        SELECT setval(pg_get_serial_sequence('staff_visibilities', 'id'), 3, true)
      SQL
    end

    safety_assured do
      add_column(:staffs, :visibility_id, :bigint, null: false, default: 2)
      add_index(:staffs, :visibility_id)
      add_foreign_key(:staffs, :staff_visibilities, column: :visibility_id)
    end
  end

  def down
    safety_assured do
      remove_foreign_key(:staffs, column: :visibility_id)
      remove_index(:staffs, :visibility_id)
      remove_column(:staffs, :visibility_id)
    end

    drop_table(:staff_visibilities)
  end
end
