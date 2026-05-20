# frozen_string_literal: true

# The repo adds foreign keys with `validate: false` and validates them in a
# follow-up migration. Under `db:schema:load` schema.rb hard-codes
# `validate: false` while the historical validate migrations are already
# recorded as run, so those constraints stay NOT VALID forever. This migration
# validates every remaining NOT VALID FK in app_principal. Each call is guarded
# by foreign_key_exists? and VALIDATE CONSTRAINT is a no-op on already-valid
# constraints, so it is safe to re-run / re-list.
class ValidateRemainingAppPrincipalForeignKeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  FOREIGN_KEYS = [
    [:apple_auths, :users, :user_id],
    [:client_banners, :clients, :client_id],
    [:members, :member_statuses, :status_id],
    [:members, :users, :user_id],
    [:user_banners, :users, :user_id],
    [:user_client_deletions, :clients, :client_id],
    [:user_client_deletions, :users, :user_id],
    [:user_client_discoveries, :clients, :client_id],
    [:user_client_discoveries, :users, :user_id],
    [:user_client_impersonations, :clients, :client_id],
    [:user_client_impersonations, :users, :user_id],
    [:user_client_observations, :clients, :client_id],
    [:user_client_observations, :users, :user_id],
    [:user_client_revocations, :clients, :client_id],
    [:user_client_revocations, :users, :user_id],
    [:user_client_suspensions, :clients, :client_id],
    [:user_client_suspensions, :users, :user_id],
    [:user_clients, :clients, :client_id],
    [:user_clients, :users, :user_id],
    [:user_emails, :users, :user_id],
    [:user_members, :members, :member_id],
    [:user_members, :users, :user_id],
    [:user_memberships, :users, :user_id],
    [:user_one_time_passwords, :users, :user_id],
    [:user_passkeys, :user_passkey_statuses, :status_id],
    [:user_passkeys, :users, :user_id],
    [:user_secrets, :users, :user_id],
    [:user_social_apples, :users, :user_id],
    [:user_social_googles, :users, :user_id],
    [:user_telephones, :users, :user_id],
    [:users, :user_multi_factor_statuses, :multi_factor_status_id],
    [:users, :user_multi_factors, :multi_factor_id],
  ].freeze

  def up
    FOREIGN_KEYS.each do |from_table, to_table, column|
      next unless foreign_key_exists?(from_table, to_table, column: column)

      validate_foreign_key(from_table, to_table, column: column)
    end
  end

  def down
    # NOT VALID -> VALID is not meaningfully reversible; intentionally a no-op.
  end
end
