# frozen_string_literal: true

class MoveAdminReferenceToAdmins < ActiveRecord::Migration[8.2]
  def change
    safety_assured { remove_reference(:staffs, :admin, foreign_key: true, if_exists: true) }

    safety_assured do
      add_reference(
        :operators,
        :staff,
        foreign_key: { to_table: :staffs, validate: false },
        type: :bigint,
      )
    end
  end
end
