# frozen_string_literal: true

class RenameCustomerActorToVisitor < ActiveRecord::Migration[8.2]
  TABLE_RENAMES = {
    customer_statuses: :visitor_statuses,
    customer_visibilities: :visitor_visibilities,
    customers: :visitors,
    customer_email_statuses: :visitor_email_statuses,
    customer_telephone_statuses: :visitor_telephone_statuses,
    customer_secret_statuses: :visitor_secret_statuses,
    customer_secret_kinds: :visitor_secret_kinds,
    customer_passkey_statuses: :visitor_passkey_statuses,
    customer_emails: :visitor_emails,
    customer_telephones: :visitor_telephones,
    customer_secrets: :visitor_secrets,
    customer_passkeys: :visitor_passkeys,
  }.freeze

  COLUMN_RENAMES = {
    visitor_emails: {
      customer_id: :visitor_id,
      customer_email_status_id: :visitor_email_status_id,
    },
    visitor_telephones: {
      customer_id: :visitor_id,
      customer_telephone_status_id: :visitor_telephone_status_id,
    },
    visitor_secrets: {
      customer_id: :visitor_id,
      customer_secret_status_id: :visitor_secret_status_id,
      customer_secret_kind_id: :visitor_secret_kind_id,
    },
    visitor_passkeys: {
      customer_id: :visitor_id,
    },
  }.freeze

  def up
    safety_assured do
      rename_tables(TABLE_RENAMES)
      rename_columns(COLUMN_RENAMES)
      rename_database_objects("customer", "visitor")
      rename_database_objects("customers", "visitors")
    end
  end

  def down
    safety_assured do
      rename_columns(reverse_column_renames(COLUMN_RENAMES))
      rename_tables(TABLE_RENAMES.invert)
      rename_database_objects("visitor", "customer")
      rename_database_objects("visitors", "customers")
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

  def reverse_column_renames(renames)
    renames.transform_values(&:invert)
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
