# frozen_string_literal: true

class CreateStaffs < ActiveRecord::Migration[7.2]
  def change
    create_table(:staffs) do |t|
      t.string(:webauthn_id)
      t.timestamps
    end
  end
end
