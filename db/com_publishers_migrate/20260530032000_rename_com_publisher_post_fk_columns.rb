# frozen_string_literal: true

class RenameComPublisherPostFkColumns < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      rename_column :com_post_categorizations, :com_post_category_master_id, :com_post_category_id
      rename_column :com_post_taggings, :com_post_tag_master_id, :com_post_tag_id
    end
  end
end
