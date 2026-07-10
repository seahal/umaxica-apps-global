# frozen_string_literal: true

class FixDatabaseConsistencyIdentity < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    # Remove redundant indexes
    remove_index(:user_clients, :user_id, if_exists: true)
    remove_index(:staff_operators, :staff_id, if_exists: true)
    remove_index(:divisions, :parent_id, if_exists: true)
    remove_index(:departments, :parent_id, if_exists: true)

    # Add NOT NULL constraint to operators.staff_id using safe approach
    unless column_null?(:operators, :staff_id) == false
      add_check_constraint(
        :operators, "staff_id IS NOT NULL",
        name: "operators_staff_id_null", validate: false,
      )
      validate_check_constraint(:operators, name: "operators_staff_id_null")
      change_column_null(:operators, :staff_id, false)
      remove_check_constraint(:operators, name: "operators_staff_id_null")
    end

    # Add unique indexes for case-insensitive lookups on status tables
    add_index_if_not_exists(
      :division_statuses, "lower(id)",
      name: "index_division_statuses_on_lower_id",
      unique: true, algorithm: :concurrently,
    )

    add_index_if_not_exists(
      :department_statuses, "lower(id)",
      name: "index_department_statuses_on_lower_id",
      unique: true, algorithm: :concurrently,
    )

    add_index_if_not_exists(
      :admin_identity_statuses, "lower(id)",
      name: "index_admin_identity_statuses_on_lower_id",
      unique: true, algorithm: :concurrently,
    )

    # Add foreign key for post versions
    # Add foreign key for post versions (Moved to avatars_migrate)

    # Add foreign key for self-referential division parent
    return if foreign_key_exists?(:divisions, :divisions, column: :parent_id)

    add_foreign_key(:divisions, :divisions, column: :parent_id, validate: false)
    validate_foreign_key(:divisions, :divisions)

    # Add foreign key for user owned_clients

    # Add foreign key for client avatars
    # Add foreign key for client avatars (Moved/Removed due to cross-db)
  end

  private

  def add_index_if_not_exists(table, column, **options)
    index_name = options[:name]
    return if connection.indexes(table).any? { |idx| idx.name == index_name }

    add_index(table, column, **options)
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.message.include?("already exists")
  end

  def column_null?(table, column)
    connection.columns(table).find { |col| col.name == column.to_s }&.null
  rescue ActiveRecord::StatementInvalid
    nil
  end

  def down
    # Revert changes in reverse order

    remove_foreign_key(:divisions, :divisions, if_exists: true)

    remove_index(
      :admin_identity_statuses, name: "index_admin_identity_statuses_on_lower_id",
                                if_exists: true,
    )

    remove_index(
      :department_statuses, name: "index_department_statuses_on_lower_id",
                            if_exists: true,
    )
    remove_index(
      :division_statuses, name: "index_division_statuses_on_lower_id",
                          if_exists: true,
    )

    change_column_null(:operators, :staff_id, true)

    # Note: Not re-adding redundant indexes as they were redundant
  end
end
