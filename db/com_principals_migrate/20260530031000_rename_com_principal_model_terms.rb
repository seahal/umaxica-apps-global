# frozen_string_literal: true

class RenameComPrincipalModelTerms < ActiveRecord::Migration[8.1]
  TABLE_RENAMES = {
    visitor_preference_items_per_pages: :visitor_preference_page_sizes,
    visitor_preference_items_per_page_options: :visitor_preference_page_size_options,
    visitor_preference_r18_display_stoppers: :visitor_preference_adult_content_gates,
    visitor_preference_r18_display_stopper_options: :visitor_preference_adult_content_gate_options,
    visitor_secret_kinds: :visitor_secret_credential_kinds,
    visitor_secret_statuses: :visitor_secret_credential_statuses,
    visitor_secrets: :visitor_secret_credentials,
    visitor_multi_factors: :visitor_mfa_levels,
    visitor_multi_factor_statuses: :visitor_mfa_statuses,
  }.freeze

  def up
    TABLE_RENAMES.each { |old_table, new_table| rename_table_strict old_table, new_table }
    safety_assured { rename_column :visitor_preferences, :items_per_page, :page_size }
  end

  def down
    safety_assured { rename_column :visitor_preferences, :page_size, :items_per_page }
    TABLE_RENAMES.to_a.reverse_each { |old_table, new_table| rename_table_strict new_table, old_table }
  end
end
