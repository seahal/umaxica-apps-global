# frozen_string_literal: true

class RenameComSettingPreferenceModelTerms < ActiveRecord::Migration[8.1]
  TABLE_RENAMES = {
    com_preference_items_per_pages: :com_preference_page_sizes,
    com_preference_items_per_page_options: :com_preference_page_size_options,
    com_preference_r18_display_stoppers: :com_preference_adult_content_gates,
    com_preference_r18_display_stopper_options: :com_preference_adult_content_gate_options,
  }.freeze

  def up
    TABLE_RENAMES.each { |old_table, new_table| rename_table_strict old_table, new_table }
  end

  def down
    TABLE_RENAMES.to_a.reverse_each { |old_table, new_table| rename_table_strict new_table, old_table }
  end
end
