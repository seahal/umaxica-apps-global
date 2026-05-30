# frozen_string_literal: true

class RenameOrgPublisherPostFkColumns < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      rename_column :org_post_categorizations, :org_post_category_master_id, :org_post_category_id
      rename_column :org_post_taggings, :org_post_tag_master_id, :org_post_tag_id
    end
  end
end
