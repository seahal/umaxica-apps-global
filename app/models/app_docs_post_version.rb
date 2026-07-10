# typed: false
# frozen_string_literal: true

class AppDocsPostVersion < AppPrincipalRecord
  self.table_name = "app_docs_post_versions"

  include Cms::PostVersionModel

  cms_post_version_model post_class_name: "AppDocsPost", revision_class_name: "AppDocsPostRevision",
                         publication_class_name: "AppDocsPostPublication", media_usage_class_name: "AppDocsMediaUsage",
                         category_assignment_class_name: "AppDocsPostVersionCategory",
                         tag_assignment_class_name: "AppDocsPostVersionTag"
end
