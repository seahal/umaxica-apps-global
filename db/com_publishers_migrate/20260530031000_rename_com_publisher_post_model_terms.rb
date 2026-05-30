# frozen_string_literal: true

class RenameComPublisherPostModelTerms < ActiveRecord::Migration[8.1]
  TABLE_RENAMES = {
    com_post_categories: :com_post_categorizations,
    com_post_tags: :com_post_taggings,
    com_post_category_masters: :com_post_categories,
    com_post_tag_masters: :com_post_tags,
  }.freeze

  def up
    TABLE_RENAMES.each { |old_table, new_table| rename_table_strict old_table, new_table }
  end

  def down
    TABLE_RENAMES.to_a.reverse_each { |old_table, new_table| rename_table_strict new_table, old_table }
  end
end
