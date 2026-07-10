# frozen_string_literal: true

class AddMissingIdentityForeignKeys < ActiveRecord::Migration[8.2]
  def change
    add_foreign_key(
      :divisions, :divisions,
      column: :parent_id, validate: false,
    )
  end
end
