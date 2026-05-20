# frozen_string_literal: true

class AddUniqueIndexToClientIdentityStatuses < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_index(
      :client_identity_statuses, "lower(id)", unique: true, name: "index_client_identity_statuses_on_lower_id",
                                              algorithm: :concurrently,
    )
  end
end
