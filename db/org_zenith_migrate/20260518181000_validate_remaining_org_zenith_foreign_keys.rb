# frozen_string_literal: true

# Validates every remaining NOT VALID FK in org_zenith. See the app_principal
# counterpart for the rationale (schema:load keeps the historical two-step
# validation from ever completing).
class ValidateRemainingOrgZenithForeignKeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  FOREIGN_KEYS = [
    [:staff_personnels, :staff_personnel_statuses, :status_id],
  ].freeze

  def up
    FOREIGN_KEYS.each do |from_table, to_table, column|
      next unless foreign_key_exists?(from_table, to_table, column: column)

      validate_foreign_key(from_table, to_table, column: column)
    end
  end

  def down
    # NOT VALID -> VALID is not meaningfully reversible; intentionally a no-op.
  end
end
