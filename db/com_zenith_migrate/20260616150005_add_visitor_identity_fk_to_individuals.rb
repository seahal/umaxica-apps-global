# frozen_string_literal: true

class AddVisitorIdentityFkToIndividuals < ActiveRecord::Migration[8.2]
  def change
    add_foreign_key :individuals, :visitor_identities, column: :visitor_identity_id, on_delete: :restrict,
                    validate: false
  end
end
