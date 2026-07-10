# frozen_string_literal: true

class RenameAppPrincipalModelTerms < ActiveRecord::Migration[8.1]
  TABLE_RENAMES = {
    client_preference_items_per_pages: :client_preference_page_sizes,
    client_preference_items_per_page_options: :client_preference_page_size_options,
    client_preference_r18_display_stoppers: :client_preference_adult_content_gates,
    client_preference_r18_display_stopper_options: :client_preference_adult_content_gate_options,
    client_one_time_passwords: :client_totp_credentials,
    client_one_time_password_statuses: :client_totp_credential_statuses,
    client_social_apples: :client_apple_identities,
    client_social_apple_statuses: :client_apple_identity_statuses,
    client_social_googles: :client_google_identities,
    client_social_google_statuses: :client_google_identity_statuses,
    client_secret_kinds: :client_secret_credential_kinds,
    client_secret_statuses: :client_secret_credential_statuses,
    client_secrets: :client_secret_credentials,
    client_multi_factors: :client_mfa_levels,
    client_multi_factor_statuses: :client_mfa_statuses,
  }.freeze

  def up
    TABLE_RENAMES.each { |old_table, new_table| rename_table_strict old_table, new_table }
    safety_assured { rename_column :client_preferences, :items_per_page, :page_size }
  end

  def down
    safety_assured { rename_column :client_preferences, :page_size, :items_per_page }
    TABLE_RENAMES.to_a.reverse_each { |old_table, new_table| rename_table_strict new_table, old_table }
  end
end
