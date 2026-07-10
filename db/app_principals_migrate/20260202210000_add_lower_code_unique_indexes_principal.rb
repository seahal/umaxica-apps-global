# frozen_string_literal: true

class AddLowerCodeUniqueIndexesPrincipal < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLES = %w(
    client_statuses
    user_email_statuses
    user_one_time_password_statuses
    user_passkey_statuses
    user_secret_kinds
    user_secret_statuses
    user_social_apple_statuses
    user_social_google_statuses
    user_statuses
    user_telephone_statuses
  ).freeze

  def up
    safety_assured do
      TABLES.each do |table|
        add_lower_code_index(table)
      end
    end
  end

  def down
    TABLES.each do |table|
      index_name = "index_#{table}_on_lower_code"
      remove_index(table, name: index_name) if index_exists?(table, nil, name: index_name)
    end
  end

  private

  def add_lower_code_index(table)
    return unless table_exists?(table) && column_exists?(table, :code)

    index_name = "index_#{table}_on_lower_code"
    return if index_exists?(table, nil, name: index_name)

    add_index(table, "lower(code)", unique: true, name: index_name, algorithm: :concurrently)
  end
end
