# frozen_string_literal: true

class AddDepartmentToAdmins < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_reference(
      :operators, :department,
      type: :bigint,
      index: { algorithm: :concurrently },
      foreign_key: { to_table: :departments, validate: false },
    )
  end
end
