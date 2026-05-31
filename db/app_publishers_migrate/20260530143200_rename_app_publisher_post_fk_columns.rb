# frozen_string_literal: true

class RenameAppPublisherPostFkColumns < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      rename_column :app_post_categorizations, :app_post_category_master_id, :app_post_category_id
      rename_column :app_post_taggings, :app_post_tag_master_id, :app_post_tag_id
    end
  end
end
