# frozen_string_literal: true

class RemoveRedundantIndexesOperatorDepartments < ActiveRecord::Migration[8.2]
  def change
    if index_exists?(:departments, :department_status_id, name: :index_departments_on_department_status_id)
      remove_index(:departments, column: :department_status_id, name: :index_departments_on_department_status_id)
    end

    if index_exists?(
      :departments, %i(department_status_id parent_id),
      name: :index_departments_on_department_status_id_and_parent_id,
    )
      remove_index(
        :departments, column: %i(department_status_id parent_id),
                      name: :index_departments_on_department_status_id_and_parent_id,
      )
    end
  end
end
