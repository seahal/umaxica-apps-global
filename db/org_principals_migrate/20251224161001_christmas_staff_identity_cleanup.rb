# frozen_string_literal: true

class ChristmasStaffIdentityCleanup < ActiveRecord::Migration[8.2]
  def change
    # Staff Audits
    set_defaults_and_nulls(:staff_identity_audits, text_cols: [:previous_value])
  end

  private

  def set_defaults_and_nulls(table, text_cols: [])
    text_cols.each do |col|
      up_only { execute("UPDATE #{table} SET #{col} = '' WHERE #{col} IS NULL") }
      change_column_default(table, col, from: nil, to: "")
      change_column_null(table, col, false)
    end
  end
end
