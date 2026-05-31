# frozen_string_literal: true

class RenameOrgPublisherPostModelTerms < ActiveRecord::Migration[8.1]
  TABLE_RENAMES = {
    org_post_categories: :org_post_categorizations,
    org_post_tags: :org_post_taggings,
    org_post_category_masters: :org_post_categories,
    org_post_tag_masters: :org_post_tags,
  }.freeze

  def up
    TABLE_RENAMES.each { |old_table, new_table| rename_table_strict old_table, new_table }
  end

  def down
    TABLE_RENAMES.to_a.reverse_each { |old_table, new_table| rename_table_strict new_table, old_table }
  end
end
