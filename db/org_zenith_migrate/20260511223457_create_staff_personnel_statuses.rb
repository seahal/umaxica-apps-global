# frozen_string_literal: true

class CreateStaffPersonnelStatuses < ActiveRecord::Migration[8.2]
  def change
    create_table(:staff_personnel_statuses, id: :bigserial)
  end
end
