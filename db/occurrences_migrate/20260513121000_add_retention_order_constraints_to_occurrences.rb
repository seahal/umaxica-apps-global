# frozen_string_literal: true

class AddRetentionOrderConstraintsToOccurrences < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLES = %i[
    area_occurrences
    customer_occurrences
    domain_occurrences
    email_occurrences
    ip_occurrences
    jwt_occurrences
    staff_occurrences
    telephone_occurrences
    user_occurrences
    zip_occurrences
  ].freeze

  def up
    TABLES.each do |table_name|
      next unless table_exists?(table_name)
      next unless column_exists?(table_name, :lapses_at) && column_exists?(table_name, :purge_at)

      constraint_name = constraint_name_for(table_name)
      unless check_constraint_exists?(table_name, name: constraint_name)
        add_check_constraint(
          table_name,
          "lapses_at <= purge_at",
          name: constraint_name,
          validate: false,
        )
      end

      validate_check_constraint(table_name, name: constraint_name)
    end
  end

  def down
    TABLES.each do |table_name|
      constraint_name = constraint_name_for(table_name)
      next unless table_exists?(table_name)
      next unless check_constraint_exists?(table_name, name: constraint_name)

      remove_check_constraint(table_name, name: constraint_name)
    end
  end

  private

  def constraint_name_for(table_name)
    "chk_#{table_name}_retention_order"
  end
end
