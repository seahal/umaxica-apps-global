# frozen_string_literal: true

class RenameAppPublisherPostModelTerms < ActiveRecord::Migration[8.1]
  TABLE_RENAMES = {
    app_post_categories: :app_post_categorizations,
    app_post_tags: :app_post_taggings,
    app_post_category_masters: :app_post_categories,
    app_post_tag_masters: :app_post_tags,
  }.freeze

  def up
    TABLE_RENAMES.each { |old_table, new_table| rename_table_strict old_table, new_table }
  end

  def down
    TABLE_RENAMES.to_a.reverse_each { |old_table, new_table| rename_table_strict new_table, old_table }
  end
end
