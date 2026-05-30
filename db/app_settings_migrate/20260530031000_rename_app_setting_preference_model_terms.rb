# frozen_string_literal: true

class RenameAppSettingPreferenceModelTerms < ActiveRecord::Migration[8.1]
  TABLE_RENAMES = {
    app_preference_items_per_pages: :app_preference_page_sizes,
    app_preference_items_per_page_options: :app_preference_page_size_options,
    app_preference_r18_display_stoppers: :app_preference_adult_content_gates,
    app_preference_r18_display_stopper_options: :app_preference_adult_content_gate_options,
  }.freeze

  def up
    TABLE_RENAMES.each { |old_table, new_table| rename_table_strict old_table, new_table }
  end

  def down
    TABLE_RENAMES.to_a.reverse_each { |old_table, new_table| rename_table_strict new_table, old_table }
  end
end
