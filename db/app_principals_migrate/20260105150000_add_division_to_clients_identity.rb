# frozen_string_literal: true

class AddDivisionToClientsIdentity < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_reference(:clients, :division, type: :bigint, index: { algorithm: :concurrently })
  end
end
