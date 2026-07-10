# frozen_string_literal: true

class RemoveRedundantCompanyUnitClosuresIndex < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    remove_index(:company_unit_closures, name: "index_company_unit_closures_on_ancestor_id", algorithm: :concurrently) if
      index_exists?(:company_unit_closures, name: "index_company_unit_closures_on_ancestor_id")
  end

  def down
    add_index(:company_unit_closures, :ancestor_id, name: "index_company_unit_closures_on_ancestor_id", algorithm: :concurrently) unless
      index_exists?(:company_unit_closures, name: "index_company_unit_closures_on_ancestor_id")
  end
end
