# frozen_string_literal: true

class ValidateFixDatabaseConsistencyIdentityRelations < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    if table_exists?(:workspaces) && table_exists?(:workspace_statuses) &&
        foreign_key_exists?(:workspaces, :workspace_statuses, column: :workspace_status_id)
      validate_foreign_key(:workspaces, :workspace_statuses)
    end

    if table_exists?(:departments)
      if table_exists?(:department_statuses) &&
          foreign_key_exists?(:departments, :department_statuses, column: :department_status_id)
        validate_foreign_key(:departments, :department_statuses)
      end

      if table_exists?(:workspaces) &&
          foreign_key_exists?(:departments, :workspaces, column: :workspace_id)
        validate_foreign_key(:departments, :workspaces)
      end

      if foreign_key_exists?(:departments, :departments, column: :parent_id)
        validate_foreign_key(:departments, :departments)
      end
    end

    if table_exists?(:divisions) && table_exists?(:workspaces) &&
        foreign_key_exists?(:divisions, :workspaces, column: :organization_id)
      validate_foreign_key(:divisions, :workspaces)
    end

    if table_exists?(:clients) && table_exists?(:divisions) &&
        foreign_key_exists?(:clients, :divisions)
      validate_foreign_key(:clients, :divisions)
    end

    if table_exists?(:operators) && table_exists?(:departments) &&
        foreign_key_exists?(:operators, :departments)
      validate_foreign_key(:operators, :departments)
    end
  end

  def down
    # no-op
  end
end
