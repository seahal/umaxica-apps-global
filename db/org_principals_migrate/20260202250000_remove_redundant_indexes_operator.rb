# frozen_string_literal: true

class RemoveRedundantIndexesOperator < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      # Division
      if index_exists?(:divisions, :division_status_id, name: :index_divisions_on_division_status_id)
        remove_index(:divisions, name: :index_divisions_on_division_status_id, algorithm: :concurrently)
      end
      # Department
      if index_exists?(:departments, :department_status_id, name: :index_departments_on_department_status_id)
        remove_index(:departments, name: :index_departments_on_department_status_id, algorithm: :concurrently)
      end
    end
  end

  def down
    safety_assured do
      add_index(:divisions, :division_status_id, name: :index_divisions_on_division_status_id, algorithm: :concurrently)
      add_index(
        :departments, :department_status_id, name: :index_departments_on_department_status_id,
                                             algorithm: :concurrently,
      )
    end
  end
end
