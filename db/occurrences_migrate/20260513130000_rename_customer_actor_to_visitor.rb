# frozen_string_literal: true

class RenameCustomerActorToVisitor < ActiveRecord::Migration[8.2]
  TABLE_RENAMES = {
    area_customer_occurrences: :area_visitor_occurrences,
    customer_occurrence_statuses: :visitor_occurrence_statuses,
    customer_occurrences: :visitor_occurrences,
    email_customer_occurrences: :email_visitor_occurrences,
    ip_customer_occurrences: :ip_visitor_occurrences,
  }.freeze

  COLUMN_RENAMES = {
    area_visitor_occurrences: {
      customer_occurrence_id: :visitor_occurrence_id,
    },
    email_visitor_occurrences: {
      customer_occurrence_id: :visitor_occurrence_id,
    },
    ip_visitor_occurrences: {
      customer_occurrence_id: :visitor_occurrence_id,
    },
  }.freeze

  def up
    safety_assured do
      rename_tables(TABLE_RENAMES)
      rename_columns(COLUMN_RENAMES)
      rename_database_objects("customer", "visitor")
    end
  end

  def down
    safety_assured do
      rename_columns(COLUMN_RENAMES.transform_values(&:invert))
      rename_tables(TABLE_RENAMES.invert)
      rename_database_objects("visitor", "customer")
    end
  end

  private

  def rename_tables(renames)
    renames.each do |old_name, new_name|
      rename_table(old_name, new_name) if table_exists?(old_name) && !table_exists?(new_name)
    end
  end

  def rename_columns(renames)
    renames.each do |table_name, columns|
      next unless table_exists?(table_name)

      columns.each do |old_name, new_name|
        rename_column(table_name, old_name, new_name) if column_exists?(table_name, old_name)
      end
    end
  end

  def rename_database_objects(old_fragment, new_fragment)
    connection.tables.each do |table_name|
      indexes(table_name).each do |index|
        next unless index.name.include?(old_fragment)

        new_name = index.name.gsub(old_fragment, new_fragment)
        rename_index(table_name, index.name, new_name) unless index_name_exists?(table_name, new_name)
      end

      next unless respond_to?(:rename_check_constraint)

      check_constraints(table_name).each do |constraint|
        next unless constraint.name.include?(old_fragment)

        new_name = constraint.name.gsub(old_fragment, new_fragment)
        rename_check_constraint(table_name, constraint.name, new_name)
      end
    end
  end
end
