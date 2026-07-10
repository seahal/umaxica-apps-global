# frozen_string_literal: true

class AddMissingUniqueIndexesPrincipal < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      # UserTelephone
      unless index_exists?(:user_telephones, "lower(number)", unique: true)
        add_index(
          :user_telephones, "lower(number)", unique: true, name: "index_user_telephones_on_lower_number",
                                             algorithm: :concurrently,
        )
      end
    end
  end

  def down
  end
end
