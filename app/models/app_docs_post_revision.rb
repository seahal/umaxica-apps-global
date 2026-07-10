# typed: false
# frozen_string_literal: true

class AppDocsPostRevision < AppPrincipalRecord
  self.table_name = "app_docs_post_revisions"

  include Cms::PostRevisionModel

  cms_post_revision_model post_class_name: "AppDocsPost", revision_class_name: "AppDocsPostRevision",
                          version_class_name: "AppDocsPostVersion", media_usage_class_name: "AppDocsMediaUsage",
                          category_assignment_class_name: "AppDocsPostRevisionCategory",
                          tag_assignment_class_name: "AppDocsPostRevisionTag"
end
