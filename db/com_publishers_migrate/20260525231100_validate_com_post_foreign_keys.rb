# frozen_string_literal: true

class ValidateComPostForeignKeys < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key(:posts, :post_statuses)
    validate_foreign_key(:post_categories, :post_category_masters)
    validate_foreign_key(:post_categories, :posts)
    validate_foreign_key(:post_tags, :post_tag_masters)
    validate_foreign_key(:post_tags, :posts)
    validate_foreign_key(:post_reviews, :post_review_statuses)
    validate_foreign_key(:post_reviews, :posts)
    validate_foreign_key(:post_versions, :posts)
    validate_foreign_key(:post_revisions, :posts)
    validate_foreign_key(:posts, :post_versions)
    validate_foreign_key(:posts, :post_revisions)
  end
end
