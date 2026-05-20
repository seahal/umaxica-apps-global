# frozen_string_literal: true

class ValidateMissingIdentityForeignKeys < ActiveRecord::Migration[8.2]
  def change
    validate_identity_fk(:divisions, :divisions, column: :parent_id)
  end

  private

  def validate_identity_fk(from_table, to_table, column:)
    return unless foreign_key_exists?(from_table, to_table, column: column)

    validate_foreign_key(from_table, to_table)
  end
end
