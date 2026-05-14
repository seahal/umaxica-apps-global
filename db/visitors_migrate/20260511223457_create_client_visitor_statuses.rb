# frozen_string_literal: true

class CreateClientVisitorStatuses < ActiveRecord::Migration[8.2]
  def change
    create_table(:client_visitor_statuses, id: :bigserial)
  end
end
