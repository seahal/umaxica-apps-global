# typed: false
# frozen_string_literal: true

class CreateOperatorTokenUsagesAndBindAuthorizationCodes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    create_table :operator_token_usages do |t|
      t.references :operator_token, null: false, foreign_key: { on_delete: :cascade }
      t.string :public_id, null: false, limit: 21
      t.string :oidc_client_id, null: false, limit: 64
      t.text :oidc_scope
      t.string :oidc_jti
      t.string :refresh_token_digest
      t.string :previous_refresh_token_digest
      t.datetime :refresh_token_expires_at
      t.datetime :refresh_token_rotated_at
      t.string :dpop_jkt
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.string :last_logout_status
      t.datetime :last_logout_attempted_at
      t.datetime :logged_out_at
      t.timestamps
    end

    add_index :operator_token_usages, :public_id, unique: true
    add_index :operator_token_usages,
              %i[operator_token_id oidc_client_id],
              unique: true,
              where: "revoked_at IS NULL",
              name: "idx_active_operator_token_usage_per_rp"
    add_index :operator_token_usages, :refresh_token_digest, unique: true, where: "refresh_token_digest IS NOT NULL"
    add_index :operator_token_usages, :oidc_client_id
    add_index :operator_token_usages, :revoked_at

    add_column :operator_authorization_codes, :operator_token_id, :bigint
    add_index :operator_authorization_codes, :operator_token_id, algorithm: :concurrently, if_not_exists: true
    add_foreign_key :operator_authorization_codes, :operator_tokens, on_delete: :cascade, validate: false
  end
end
