# frozen_string_literal: true

class CreateUserIdentitySecrets < ActiveRecord::Migration[8.2]
  def change
    create_table(:user_identity_secrets) do |t|
      t.references(:user, null: false, foreign_key: true, type: :bigint)
      t.string(:password_digest)
      t.datetime(:last_used_at)

      t.timestamps
    end
  end
end
