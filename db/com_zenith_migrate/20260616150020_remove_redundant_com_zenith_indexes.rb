# frozen_string_literal: true

class RemoveRedundantComZenithIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    remove_index(:company_unit_closures, name: "index_company_unit_closures_on_ancestor_id", algorithm: :concurrently) if
      index_exists?(:company_unit_closures, name: "index_company_unit_closures_on_ancestor_id")
    remove_index(:core_com_visitor_bridges, name: "index_core_com_visitor_bridges_on_visitor_id", algorithm: :concurrently) if
      index_exists?(:core_com_visitor_bridges, name: "index_core_com_visitor_bridges_on_visitor_id")
    remove_index(:visitor_oidc_connections, name: "index_visitor_oidc_connections_on_visitor_id", algorithm: :concurrently) if
      index_exists?(:visitor_oidc_connections, name: "index_visitor_oidc_connections_on_visitor_id")
  end

  def down
    add_index(:company_unit_closures, :ancestor_id, name: "index_company_unit_closures_on_ancestor_id", algorithm: :concurrently) unless
      index_exists?(:company_unit_closures, name: "index_company_unit_closures_on_ancestor_id")
    add_index(:core_com_visitor_bridges, :visitor_id, name: "index_core_com_visitor_bridges_on_visitor_id", algorithm: :concurrently) unless
      index_exists?(:core_com_visitor_bridges, name: "index_core_com_visitor_bridges_on_visitor_id")
    add_index(:visitor_oidc_connections, :visitor_id, name: "index_visitor_oidc_connections_on_visitor_id", algorithm: :concurrently) unless
      index_exists?(:visitor_oidc_connections, name: "index_visitor_oidc_connections_on_visitor_id")
  end
end
