# frozen_string_literal: true

class AddNameToOrganizationsAndOrganizationToDivisions < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    if table_exists?(:organizations) && !column_exists?(:organizations, :name)
      add_column(:organizations, :name, :string)
    end

    if table_exists?(:divisions) && column_exists?(:divisions, :organization_id)
      add_index(:divisions, :organization_id, algorithm: :concurrently) unless index_exists?(
        :divisions,
        :organization_id,
      )
    elsif table_exists?(:divisions)
      add_reference(
        :divisions, :organization, type: :bigint,
                                   index: { algorithm: :concurrently },
      )
    end
  end
end
