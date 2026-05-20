# frozen_string_literal: true

class AlignOperatorModelTableNames < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      rename_table(:operators, :operator_accounts) if table_exists?(:operators) && !table_exists?(:operator_accounts)
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
      rename_table(:operator_accounts, :operators) if table_exists?(:operator_accounts) && !table_exists?(:operators)
    end
  end

  private

  def rename_operator_account_indexes
    rename_index_if_exists(:operator_accounts, "index_operators_on_department_id", "index_operator_accounts_on_department_id")
    rename_index_if_exists(:operator_accounts, "index_operators_on_public_id", "index_operator_accounts_on_public_id")
    rename_index_if_exists(:operator_accounts, "index_operators_on_staff_id", "index_operator_accounts_on_staff_id")
    rename_index_if_exists(:operator_accounts, "index_operators_on_status_id", "index_operator_accounts_on_status_id")
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
    rename_index_if_exists(:operator_accounts, "index_operator_accounts_on_department_id", "index_operators_on_department_id")
    rename_index_if_exists(:operator_accounts, "index_operator_accounts_on_public_id", "index_operators_on_public_id")
    rename_index_if_exists(:operator_accounts, "index_operator_accounts_on_staff_id", "index_operators_on_staff_id")
    rename_index_if_exists(:operator_accounts, "index_operator_accounts_on_status_id", "index_operators_on_status_id")
  end

  def rename_index_if_exists(table_name, old_name, new_name)
    return unless table_exists?(table_name)
    return unless index_name_exists?(table_name, old_name)
    return if index_name_exists?(table_name, new_name)

    rename_index(table_name, old_name, new_name)
  end
end
