# frozen_string_literal: true

class CreateStaffOneTimePasswordStatuses < ActiveRecord::Migration[8.2]
  def change
    create_table(:staff_one_time_password_statuses, id: :string) do |t|
      t.timestamps
    end
  end
end
