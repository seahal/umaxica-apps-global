# frozen_string_literal: true

require_relative "../app_publishers_migrate/20260602010000_decommission_app_publisher_post_tables"

class DecommissionComPublisherPostTables < DecommissionAppPublisherPostTables
  def up
    %i[
      com_post_categorizations
      com_post_reviews
      com_post_revisions
      com_post_taggings
      com_post_versions
      com_posts
      com_post_categories
      com_post_tags
      com_post_review_statuses
      com_post_statuses
    ].each { |table_name| drop_table(table_name, force: :cascade) }
  end

  def down
    create_post_tables(:com)
  end
end
