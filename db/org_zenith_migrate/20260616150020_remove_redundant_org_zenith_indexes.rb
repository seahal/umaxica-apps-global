# frozen_string_literal: true

class RemoveRedundantOrgZenithIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    remove_index(:bureau_unit_closures, name: "index_bureau_unit_closures_on_ancestor_id", algorithm: :concurrently) if
      index_exists?(:bureau_unit_closures, name: "index_bureau_unit_closures_on_ancestor_id")
    remove_index(:core_org_operator_bridges, name: "index_core_org_operator_bridges_on_operator_id", algorithm: :concurrently) if
      index_exists?(:core_org_operator_bridges, name: "index_core_org_operator_bridges_on_operator_id")
  end

  def down
    add_index(:bureau_unit_closures, :ancestor_id, name: "index_bureau_unit_closures_on_ancestor_id", algorithm: :concurrently) unless
      index_exists?(:bureau_unit_closures, name: "index_bureau_unit_closures_on_ancestor_id")
    add_index(:core_org_operator_bridges, :operator_id, name: "index_core_org_operator_bridges_on_operator_id", algorithm: :concurrently) unless
      index_exists?(:core_org_operator_bridges, name: "index_core_org_operator_bridges_on_operator_id")
  end
end
