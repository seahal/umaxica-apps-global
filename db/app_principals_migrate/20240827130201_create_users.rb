# frozen_string_literal: true

# TODO: Use table partitioning.

class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    # FIXME: need hashed partition.
    create_table(:users) do |t|
      t.string(:webauthn_id)
      t.timestamps
    end
  end
end
