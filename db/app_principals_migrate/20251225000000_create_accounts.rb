# frozen_string_literal: true

# db/migrate/20251226000000_create_accounts.rb
class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    # Account is the canonical identity record.
    create_table(:accounts) do |t|
      # Columns for delegated types.
      t.string(:accountable_type, null: false)
      t.bigint(:accountable_id,   null: false)

      # Shared attributes (NULL not allowed).
      t.string(:email, null: false, index: { unique: true })
      t.string(:password_digest, null: false)

      t.timestamps
    end
  end
end
