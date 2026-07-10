# frozen_string_literal: true

class AddPublicIdAndTitleToUserOneTimePasswords < ActiveRecord::Migration[8.2]
  def change
    safety_assured do
      change_table(:user_one_time_passwords, bulk: true) do |t|
        t.string(:public_id, limit: 21)
        t.string(:title, limit: 32)
      end

      add_index(:user_one_time_passwords, :public_id, unique: true)
    end
  end
end
