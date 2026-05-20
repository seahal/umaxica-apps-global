# frozen_string_literal: true

class FixPrimaryKeyTypes < ActiveRecord::Migration[8.2]
  def up
    # Change primary key types from int to bigint (safe in reset/dev/test).
    migrate_pk_type(:staff_identity_passkey_statuses, :bigint, using: "id::bigint", from: :integer)
    migrate_pk_type(:division_statuses, :bigint, using: "id::bigint", from: :integer)
    migrate_pk_type(:department_statuses, :bigint, using: "id::bigint", from: :integer)
    migrate_pk_type(:client_identity_statuses, :bigint, using: "id::bigint", from: :integer)
    migrate_pk_type(:admin_identity_statuses, :bigint, using: "id::bigint", from: :integer)
  end

  def down
    # Revert to int if needed (though generally not recommended)
    migrate_pk_type(:staff_identity_passkey_statuses, :int, using: "id::int", from: :bigint)
    migrate_pk_type(:division_statuses, :int, using: "id::int", from: :bigint)
    migrate_pk_type(:department_statuses, :int, using: "id::int", from: :bigint)
    migrate_pk_type(:client_identity_statuses, :int, using: "id::int", from: :bigint)
    migrate_pk_type(:admin_identity_statuses, :int, using: "id::int", from: :bigint)
  end

  private

  def migrate_pk_type(table, to_type, using:, from:)
    column = column_for(table, :id)
    return unless column
    return unless column.type == from

    safety_assured do
      change_column(table, :id, to_type, using: using)
    end
  end

  def column_for(table, name)
    connection.columns(table).find { |col| col.name == name.to_s }
  rescue ActiveRecord::StatementInvalid
    nil
  end
end
