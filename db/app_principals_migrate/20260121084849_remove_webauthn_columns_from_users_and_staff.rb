# frozen_string_literal: true

class RemoveWebauthnColumnsFromUsersAndStaff < ActiveRecord::Migration[8.2]
  def change
    safety_assured do
      if table_exists?(:users) && column_exists?(:users, :webauthn_id)
        remove_column(:users, :webauthn_id, :string)
      end

      if table_exists?(:staffs) && column_exists?(:staffs, :webauthn_id)
        remove_column(:staffs, :webauthn_id, :string)
      end
    end
  end
end
