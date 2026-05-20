# frozen_string_literal: true

class CreateStaffIdentityEmails < ActiveRecord::Migration[8.0]
  def change
    create_table(:staff_identity_emails) do |t|
      t.references(:staff, type: :bigint, foreign_key: true)
      t.string(:address)
      t.timestamps
    end
  end
end
