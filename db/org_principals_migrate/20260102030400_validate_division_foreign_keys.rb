# frozen_string_literal: true

class ValidateDivisionForeignKeys < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key(:divisions, :division_statuses)
  end
end
