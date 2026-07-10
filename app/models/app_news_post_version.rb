# typed: false
# frozen_string_literal: true

class AppNewsPostVersion < AppPrincipalRecord
  self.table_name = "app_news_post_versions"

  include Cms::PostVersionModel

  cms_post_version_model post_class_name: "AppNewsPost", revision_class_name: "AppNewsPostRevision",
                         publication_class_name: "AppNewsPostPublication", media_usage_class_name: "AppNewsMediaUsage",
                         category_assignment_class_name: "AppNewsPostVersionCategory",
                         tag_assignment_class_name: "AppNewsPostVersionTag"
end
