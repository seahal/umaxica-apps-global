# frozen_string_literal: true

require_relative "../app_publishers_migrate/20260602010000_decommission_app_publisher_post_tables"

class DecommissionOrgPublisherPostTables < DecommissionAppPublisherPostTables
  def up
    %i[
      org_post_categorizations
      org_post_reviews
      org_post_revisions
      org_post_taggings
      org_post_versions
      org_posts
      org_post_categories
      org_post_tags
      org_post_review_statuses
      org_post_statuses
    ].each { |table_name| drop_table(table_name, force: :cascade) }
  end

  def down
    create_post_tables(:org)
  end
end
