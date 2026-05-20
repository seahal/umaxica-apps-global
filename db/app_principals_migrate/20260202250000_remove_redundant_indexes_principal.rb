# frozen_string_literal: true

class RemoveRedundantIndexesPrincipal < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      if index_exists?(:user_telephones, "lower((number)::text)", name: :index_user_identity_telephones_on_lower_number)
        remove_index(:user_telephones, name: :index_user_identity_telephones_on_lower_number, algorithm: :concurrently)
      end
    end
  end

  def down
    safety_assured do
      add_index(
        :user_telephones, "lower(number)", name: :index_user_identity_telephones_on_lower_number,
                                           algorithm: :concurrently,
      )
    end
  end
end
