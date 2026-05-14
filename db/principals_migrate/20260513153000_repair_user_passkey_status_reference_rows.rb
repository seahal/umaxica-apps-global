# frozen_string_literal: true

class RepairUserPasskeyStatusReferenceRows < ActiveRecord::Migration[8.2]
  USER_PASSKEY_STATUSES = {
    1 => "ACTIVE",
    2 => "DISABLED",
    3 => "REVOKED",
    4 => "DELETED",
    5 => "NEYO",
  }.freeze

  def up
    return unless table_exists?(:user_passkey_statuses)

    safety_assured do
      seed_reference_rows(:user_passkey_statuses, USER_PASSKEY_STATUSES)
    end

    return unless table_exists?(:user_passkeys) && column_exists?(:user_passkeys, :status_id)

    change_column_default(:user_passkeys, :status_id, from: 0, to: 1) if passkeys_status_default?(0)
  end

  def down
    return unless table_exists?(:user_passkeys) && column_exists?(:user_passkeys, :status_id)

    change_column_default(:user_passkeys, :status_id, from: 1, to: 0) if passkeys_status_default?(1)
  end

  private

  def seed_reference_rows(table_name, mapping)
    has_code = column_exists?(table_name, :code)

    mapping.each do |id, code|
      insert_row(table_name, id, code, has_code)
    end

    reset_pk_sequence!(table_name)
  end

  def insert_row(table_name, id, code, has_code)
    columns = has_code ? %i(id code) : %i(id)
    values = has_code ? [id, code] : [id]

    insert_statement = Arel::InsertManager.new
    insert_statement.into(Arel::Table.new(table_name))
    insert_statement.columns.concat(
      columns.map { |column| Arel::Attributes::Attribute.new(insert_statement.ast.relation, column) },
    )
    insert_statement.values = insert_statement.create_values_list([values])

    sql = "#{insert_statement.to_sql} ON CONFLICT (id) DO NOTHING"
    connection.insert(sql)
  end

  def reset_pk_sequence!(table_name)
    connection.reset_pk_sequence!(table_name)
  end

  def passkeys_status_default?(expected)
    column = columns(:user_passkeys).find { |candidate| candidate.name == "status_id" }
    column&.default.to_i == expected
  end
end
