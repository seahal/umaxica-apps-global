# typed: false
# frozen_string_literal: true

class AppNewsPostRevisionTag < AppPrincipalRecord
  self.table_name = "app_news_post_revision_tags"

  include Cms::TagAssignmentModel

  cms_tag_assignment_model owner_name: :post_revision, owner_class_name: "AppNewsPostRevision",
                           owner_foreign_key: :post_revision_id, owner_inverse: :revision_tags, tag_class_name: "AppNewsTag"
end
