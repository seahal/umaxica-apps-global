# frozen_string_literal: true

# TODO: Use table partitioning.

class CreateStaffs < ActiveRecord::Migration[7.2]
  def change
    # FIXME: need hashed partition.
    create_table(:staffs) do |t|
      t.string(:webauthn_id)
      t.timestamps
    end
  end
end
