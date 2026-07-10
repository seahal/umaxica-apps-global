# typed: false
# frozen_string_literal: true

class OrgDocsPostRevision < OrgPrincipalRecord
  self.table_name = "org_docs_post_revisions"

  include Cms::PostRevisionModel

  cms_post_revision_model post_class_name: "OrgDocsPost", revision_class_name: "OrgDocsPostRevision",
                          version_class_name: "OrgDocsPostVersion", media_usage_class_name: "OrgDocsMediaUsage",
                          category_assignment_class_name: "OrgDocsPostRevisionCategory",
                          tag_assignment_class_name: "OrgDocsPostRevisionTag"
end
