# frozen_string_literal: true

class AddIdFormatConstraintsToOperatorTables < ActiveRecord::Migration[8.2]
  def up
    tables_to_constrain.each do |table_name|
      constraint_name = "#{table_name}_id_format_check"
      next if check_constraint_exists?(table_name, name: constraint_name)

      safety_assured do
        execute(<<~SQL.squish)
          ALTER TABLE #{table_name}
          ADD CONSTRAINT #{constraint_name}
          CHECK (id::text ~ '^[A-Z0-9_]+$')
        SQL
      end
    end
  end

  def down
    tables_to_constrain.each do |table_name|
      safety_assured do
        execute(<<~SQL.squish)
          ALTER TABLE #{table_name}
          DROP CONSTRAINT IF EXISTS #{table_name}_id_format_check
        SQL
      end
    end
  end

  private

  def tables_to_constrain
    %w(
      staff_telephone_statuses
      staff_statuses
      staff_secret_statuses
      staff_passkey_statuses
      staff_email_statuses
      organization_statuses
      division_statuses
      workspace_statuses
      operator_statuses
    )
  end
end
