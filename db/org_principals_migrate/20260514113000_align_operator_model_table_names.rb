# frozen_string_literal: true

class AlignOperatorModelTableNames < ActiveRecord::Migration[8.2]
  # The pre-consolidation `operators` table (department_id/status_id-shaped) is renamed to
  # `legacy_operator_department_accounts`, not `operator_accounts`. After the org_principal/org_zenith
  # physical consolidation, `operator_accounts` is owned by the org_zenith migration path (see
  # db/org_zenith_migrate/20260519161001_rename_org_rp_tables.rb, which renames the live
  # `staff_accounts` table -- matching the current `OperatorAccount` model -- to `operator_accounts`).
  # This table is no longer referenced by any model; its responsibilities moved to
  # `operator_workspace_accounts` / `operator_workspace_account_memberships`.
  LEGACY_OPERATOR_ACCOUNTS_TABLE = :legacy_operator_department_accounts

  def up
    safety_assured do
      if table_exists?(:operators) && !table_exists?(LEGACY_OPERATOR_ACCOUNTS_TABLE)
        rename_table(:operators, LEGACY_OPERATOR_ACCOUNTS_TABLE)
      end
      rename_operator_account_indexes

      rename_table(:staffs, :operators) if table_exists?(:staffs) && !table_exists?(:operators)
      rename_operator_indexes
    end
  end

  def down
    safety_assured do
      rename_operator_indexes_back
      rename_table(:operators, :staffs) if table_exists?(:operators) && !table_exists?(:staffs)

      rename_operator_account_indexes_back
      if table_exists?(LEGACY_OPERATOR_ACCOUNTS_TABLE) && !table_exists?(:operators)
        rename_table(LEGACY_OPERATOR_ACCOUNTS_TABLE, :operators)
      end
    end
  end

  private

  def rename_operator_account_indexes
    rename_index_if_exists(LEGACY_OPERATOR_ACCOUNTS_TABLE, "index_operators_on_department_id", "index_legacy_operator_department_accounts_on_department_id")
    rename_index_if_exists(LEGACY_OPERATOR_ACCOUNTS_TABLE, "index_operators_on_public_id", "index_legacy_operator_department_accounts_on_public_id")
    rename_index_if_exists(LEGACY_OPERATOR_ACCOUNTS_TABLE, "index_operators_on_staff_id", "index_legacy_operator_department_accounts_on_staff_id")
    rename_index_if_exists(LEGACY_OPERATOR_ACCOUNTS_TABLE, "index_operators_on_status_id", "index_legacy_operator_department_accounts_on_status_id")
  end

  def rename_operator_indexes
    rename_index_if_exists(:operators, "index_staffs_on_multi_factor_id", "index_operators_on_multi_factor_id")
    rename_index_if_exists(:operators, "index_staffs_on_public_id", "index_operators_on_public_id")
    rename_index_if_exists(:operators, "index_staffs_on_purge_at", "index_operators_on_purge_at")
    rename_index_if_exists(:operators, "index_staffs_on_status_id", "index_operators_on_status_id")
    rename_index_if_exists(:operators, "index_staffs_on_visibility_id", "index_operators_on_visibility_id")
    rename_index_if_exists(:operators, "index_staffs_on_withdrawn_at", "index_operators_on_withdrawn_at")
  end

  def rename_operator_indexes_back
    rename_index_if_exists(:operators, "index_operators_on_multi_factor_id", "index_staffs_on_multi_factor_id")
    rename_index_if_exists(:operators, "index_operators_on_public_id", "index_staffs_on_public_id")
    rename_index_if_exists(:operators, "index_operators_on_purge_at", "index_staffs_on_purge_at")
    rename_index_if_exists(:operators, "index_operators_on_status_id", "index_staffs_on_status_id")
    rename_index_if_exists(:operators, "index_operators_on_visibility_id", "index_staffs_on_visibility_id")
    rename_index_if_exists(:operators, "index_operators_on_withdrawn_at", "index_staffs_on_withdrawn_at")
  end

  def rename_operator_account_indexes_back
    rename_index_if_exists(LEGACY_OPERATOR_ACCOUNTS_TABLE, "index_legacy_operator_department_accounts_on_department_id", "index_operators_on_department_id")
    rename_index_if_exists(LEGACY_OPERATOR_ACCOUNTS_TABLE, "index_legacy_operator_department_accounts_on_public_id", "index_operators_on_public_id")
    rename_index_if_exists(LEGACY_OPERATOR_ACCOUNTS_TABLE, "index_legacy_operator_department_accounts_on_staff_id", "index_operators_on_staff_id")
    rename_index_if_exists(LEGACY_OPERATOR_ACCOUNTS_TABLE, "index_legacy_operator_department_accounts_on_status_id", "index_operators_on_status_id")
  end

  def rename_index_if_exists(table_name, old_name, new_name)
    return unless table_exists?(table_name)
    return unless index_name_exists?(table_name, old_name)
    return if index_name_exists?(table_name, new_name)

    rename_index(table_name, old_name, new_name)
  end
end
