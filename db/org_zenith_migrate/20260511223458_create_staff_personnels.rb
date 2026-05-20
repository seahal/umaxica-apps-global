# frozen_string_literal: true

class CreateStaffPersonnels < ActiveRecord::Migration[8.2]
  def change
    create_table(:staff_personnels, id: :bigserial) do |t|
      t.string(:public_id, null: false, default: "")
      t.string(:issuer, null: false)
      t.string(:subject, null: false)
      t.string(:audience, null: false)
      t.bigint(:source_record_id, null: false)
      t.bigint(:status_id, null: false, default: 0)
      t.datetime(:last_authenticated_at)
      t.integer(:lock_version, null: false, default: 0)

      t.timestamps

      t.index(:public_id, unique: true)
      t.index(%i(issuer subject audience), unique: true)
      t.index(:source_record_id, unique: true)
      t.index(:status_id)
    end

    add_foreign_key(:staff_personnels, :staff_personnel_statuses, column: :status_id, validate: false)
  end
end
