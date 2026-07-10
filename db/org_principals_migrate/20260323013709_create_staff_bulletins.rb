# frozen_string_literal: true

class CreateStaffBulletins < ActiveRecord::Migration[8.2]
  def change
    safety_assured do
      create_table(:staff_bulletins, id: :bigserial) do |t|
        t.bigint(:staff_id, null: false)
        t.string(:public_id, limit: 21, null: false)
        t.string(:title, null: false)
        t.text(:body)
        t.datetime(:read_at)

        t.timestamps
      end

      add_index(:staff_bulletins, :staff_id)
      add_index(:staff_bulletins, :public_id, unique: true)
      add_foreign_key(:staff_bulletins, :staffs)
    end
  end
end
