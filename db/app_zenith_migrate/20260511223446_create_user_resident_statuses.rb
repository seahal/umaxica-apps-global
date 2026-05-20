# frozen_string_literal: true

class CreateUserResidentStatuses < ActiveRecord::Migration[8.2]
  def change
    create_table(:user_resident_statuses, id: :bigserial)
  end
end
