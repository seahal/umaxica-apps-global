# frozen_string_literal: true

class RenameOrgPrincipalModelTerms < ActiveRecord::Migration[8.1]
  TABLE_RENAMES = {
    operator_preference_items_per_pages: :operator_preference_page_sizes,
    operator_preference_items_per_page_options: :operator_preference_page_size_options,
    operator_preference_r18_display_stoppers: :operator_preference_adult_content_gates,
    operator_preference_r18_display_stopper_options: :operator_preference_adult_content_gate_options,
    operator_secret_kinds: :operator_secret_credential_kinds,
    operator_secret_statuses: :operator_secret_credential_statuses,
    operator_secrets: :operator_secret_credentials,
    operator_multi_factors: :operator_mfa_levels,
    operator_multi_factor_statuses: :operator_mfa_statuses,
    operator_social_googles: :operator_google_identities,
    operator_social_google_statuses: :operator_google_identity_statuses,
    operator_statuses: :operator_workspace_account_statuses,
    operator_identity_statuses: :operator_statuses,
  }.freeze

  def up
    TABLE_RENAMES.each { |old_table, new_table| rename_table_strict old_table, new_table }
    safety_assured { rename_column :operator_preferences, :items_per_page, :page_size }
  end

  def down
    safety_assured { rename_column :operator_preferences, :page_size, :items_per_page }
    TABLE_RENAMES.to_a.reverse_each { |old_table, new_table| rename_table_strict new_table, old_table }
  end
end
