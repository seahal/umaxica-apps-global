# frozen_string_literal: true

class RemoveRedundantIndexesPrincipalUserClients < ActiveRecord::Migration[8.2]
  def change
    remove_index(:user_clients, column: :user_id) if index_exists?(
      :user_clients,
      :user_id,
      name: :index_user_clients_on_user_id,
    )
  end
end
