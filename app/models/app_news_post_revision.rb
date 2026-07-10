# typed: false
# frozen_string_literal: true

class AppNewsPostRevision < AppPrincipalRecord
  self.table_name = "app_news_post_revisions"

  include Cms::PostRevisionModel

  cms_post_revision_model post_class_name: "AppNewsPost", revision_class_name: "AppNewsPostRevision",
                          version_class_name: "AppNewsPostVersion", media_usage_class_name: "AppNewsMediaUsage",
                          category_assignment_class_name: "AppNewsPostRevisionCategory",
                          tag_assignment_class_name: "AppNewsPostRevisionTag"
end
