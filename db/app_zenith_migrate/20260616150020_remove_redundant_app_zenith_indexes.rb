# frozen_string_literal: true

class RemoveRedundantAppZenithIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    remove_index(:core_app_client_bridges, name: "index_core_app_client_bridges_on_client_id", algorithm: :concurrently) if
      index_exists?(:core_app_client_bridges, name: "index_core_app_client_bridges_on_client_id")
    remove_index(:enterprise_unit_closures, name: "index_enterprise_unit_closures_on_ancestor_id", algorithm: :concurrently) if
      index_exists?(:enterprise_unit_closures, name: "index_enterprise_unit_closures_on_ancestor_id")
  end

  def down
    add_index(:core_app_client_bridges, :client_id, name: "index_core_app_client_bridges_on_client_id", algorithm: :concurrently) unless
      index_exists?(:core_app_client_bridges, name: "index_core_app_client_bridges_on_client_id")
    add_index(:enterprise_unit_closures, :ancestor_id, name: "index_enterprise_unit_closures_on_ancestor_id", algorithm: :concurrently) unless
      index_exists?(:enterprise_unit_closures, name: "index_enterprise_unit_closures_on_ancestor_id")
  end
end
