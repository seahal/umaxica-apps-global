# frozen_string_literal: true

class AddUniqueIndexesForIdentityStatusIds < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_index(
      :division_statuses, "lower(id)", unique: true, name: "index_division_statuses_on_lower_id",
                                       algorithm: :concurrently,
    )
    add_index(
      :department_statuses, "lower(id)", unique: true, name: "index_department_statuses_on_lower_id",
                                         algorithm: :concurrently,
    )

    add_index(
      :admin_identity_statuses, "lower(id)", unique: true, name: "index_admin_identity_statuses_on_lower_id",
                                             algorithm: :concurrently,
    )
  end
end
