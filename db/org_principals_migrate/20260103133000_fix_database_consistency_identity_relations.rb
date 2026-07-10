# frozen_string_literal: true

class FixDatabaseConsistencyIdentityRelations < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    if table_exists?(:client_avatar_accesses)
      remove_index(:client_avatar_accesses, :client_id) if index_exists?(:client_avatar_accesses, :client_id)
    end

    if table_exists?(:workspaces) && table_exists?(:workspace_statuses) &&
        column_exists?(:workspaces, :workspace_status_id) &&
        !foreign_key_exists?(:workspaces, :workspace_statuses, column: :workspace_status_id)
      add_foreign_key(:workspaces, :workspace_statuses, column: :workspace_status_id, validate: false)
    end

    if table_exists?(:departments)
      add_column(:departments, :department_status_id, :string, limit: 255) unless column_exists?(
        :departments,
        :department_status_id,
      )
      add_column(:departments, :workspace_id, :bigint) unless column_exists?(:departments, :workspace_id)
      add_column(:departments, :parent_id, :bigint) unless column_exists?(:departments, :parent_id)

      add_index(:departments, :department_status_id, algorithm: :concurrently) unless index_exists?(
        :departments,
        :department_status_id,
      )
      add_index(:departments, :workspace_id, algorithm: :concurrently) unless index_exists?(:departments, :workspace_id)
      add_index(:departments, :parent_id, algorithm: :concurrently) unless index_exists?(:departments, :parent_id)
      add_index(
        :departments, %i(department_status_id parent_id),
        unique: true,
        algorithm: :concurrently,
        name: "index_departments_on_status_and_parent",
      ) unless index_exists?(
        :departments,
        %i(department_status_id parent_id), name: "index_departments_on_status_and_parent",
      )

      if table_exists?(:department_statuses) && column_exists?(:departments, :department_status_id) &&
          !foreign_key_exists?(:departments, :department_statuses, column: :department_status_id)
        add_foreign_key(:departments, :department_statuses, column: :department_status_id, validate: false)
      end

      if table_exists?(:workspaces) && column_exists?(:departments, :workspace_id) &&
          !foreign_key_exists?(:departments, :workspaces, column: :workspace_id)
        add_foreign_key(:departments, :workspaces, column: :workspace_id, validate: false)
      end

      if column_exists?(:departments, :parent_id) &&
          !foreign_key_exists?(:departments, :departments, column: :parent_id)
        add_foreign_key(:departments, :departments, column: :parent_id, validate: false)
      end
    end

    if table_exists?(:divisions) && table_exists?(:workspaces) &&
        column_exists?(:divisions, :organization_id) &&
        !foreign_key_exists?(:divisions, :workspaces, column: :organization_id)
      add_foreign_key(:divisions, :workspaces, column: :organization_id, validate: false)
    end

    if table_exists?(:clients) && table_exists?(:divisions)
      remove_foreign_key(:clients, :divisions) if foreign_key_exists?(:clients, :divisions)
      unless foreign_key_exists?(:clients, :divisions)
        add_foreign_key(:clients, :divisions, on_delete: :nullify, validate: false)
      end
    end

    return unless table_exists?(:operators) && table_exists?(:departments)

    remove_foreign_key(:operators, :departments) if foreign_key_exists?(:operators, :departments)
    return if foreign_key_exists?(:operators, :departments)

    add_foreign_key(:operators, :departments, on_delete: :nullify, validate: false)

  end

  def down
    if table_exists?(:operators) && table_exists?(:departments)
      remove_foreign_key(:operators, :departments) if foreign_key_exists?(:operators, :departments)
      add_foreign_key(:operators, :departments) unless foreign_key_exists?(:operators, :departments)
    end

    if table_exists?(:clients) && table_exists?(:divisions)
      remove_foreign_key(:clients, :divisions) if foreign_key_exists?(:clients, :divisions)
      add_foreign_key(:clients, :divisions) unless foreign_key_exists?(:clients, :divisions)
    end

    if table_exists?(:divisions) && table_exists?(:workspaces)
      remove_foreign_key(:divisions, :workspaces, column: :organization_id) if foreign_key_exists?(
        :divisions,
        :workspaces, column: :organization_id,
      )
    end

    if table_exists?(:departments)
      remove_foreign_key(:departments, :department_statuses, column: :department_status_id) if foreign_key_exists?(
        :departments, :department_statuses, column: :department_status_id,
      )
      remove_foreign_key(:departments, :workspaces, column: :workspace_id) if foreign_key_exists?(
        :departments,
        :workspaces, column: :workspace_id,
      )
      remove_foreign_key(:departments, :departments, column: :parent_id) if foreign_key_exists?(
        :departments,
        :departments, column: :parent_id,
      )

      remove_index(:departments, name: "index_departments_on_status_and_parent") if index_exists?(
        :departments,
        %i(department_status_id parent_id), name: "index_departments_on_status_and_parent",
      )
      remove_index(:departments, :parent_id) if index_exists?(:departments, :parent_id)
      remove_index(:departments, :workspace_id) if index_exists?(:departments, :workspace_id)
      remove_index(:departments, :department_status_id) if index_exists?(:departments, :department_status_id)

      remove_column(:departments, :parent_id) if column_exists?(:departments, :parent_id)
      remove_column(:departments, :workspace_id) if column_exists?(:departments, :workspace_id)
      remove_column(:departments, :department_status_id) if column_exists?(:departments, :department_status_id)
    end

    if table_exists?(:workspaces) && table_exists?(:workspace_statuses)
      remove_foreign_key(:workspaces, :workspace_statuses, column: :workspace_status_id) if foreign_key_exists?(
        :workspaces, :workspace_statuses, column: :workspace_status_id,
      )
    end

    return unless table_exists?(:client_avatar_accesses)

    add_index(:client_avatar_accesses, :client_id, algorithm: :concurrently) unless index_exists?(
      :client_avatar_accesses, :client_id,
    )

  end
end
