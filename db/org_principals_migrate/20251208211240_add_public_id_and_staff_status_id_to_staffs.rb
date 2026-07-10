# frozen_string_literal: true

class AddPublicIdAndStaffStatusIdToStaffs < ActiveRecord::Migration[8.2]
  def up
    change_table(:staffs, bulk: true) do |t|
      t.string(:public_id, limit: 255)
      t.string(:staff_status_id, limit: 255, default: "NONE", null: false)
    end

    add_index(:staffs, :public_id, unique: true)
    add_index(:staffs, :staff_status_id)
    add_foreign_key(:staffs, :staff_identity_statuses, column: :staff_status_id, primary_key: :id)
  end

  def down
    remove_foreign_key(:staffs, :staff_identity_statuses)
    remove_index(:staffs, :staff_status_id)
    remove_index(:staffs, :public_id)
    change_table(:staffs, bulk: true) do |t|
      t.remove(:staff_status_id)
      t.remove(:public_id)
    end
  end
end
