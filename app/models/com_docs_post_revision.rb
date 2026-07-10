# typed: false
# frozen_string_literal: true

class ComDocsPostRevision < ComPrincipalRecord
  self.table_name = "com_docs_post_revisions"

  include Cms::PostRevisionModel

  cms_post_revision_model post_class_name: "ComDocsPost", revision_class_name: "ComDocsPostRevision",
                          version_class_name: "ComDocsPostVersion", media_usage_class_name: "ComDocsMediaUsage",
                          category_assignment_class_name: "ComDocsPostRevisionCategory",
                          tag_assignment_class_name: "ComDocsPostRevisionTag"
end
