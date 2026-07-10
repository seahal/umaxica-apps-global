# frozen_string_literal: true

class CreateUserPasskeys < ActiveRecord::Migration[8.0]
  def change
    create_table(:user_passkeys) do |t|
      t.references(:user, null: false, foreign_key: true, type: :bigint)
      t.string(:external_id)
      t.text(:public_key)
      t.integer(:sign_count)
      t.string(:user_handle)
      t.string(:name)
      t.string(:transports)

      t.timestamps
    end
    add_index(:user_passkeys, :external_id)
  end
end
