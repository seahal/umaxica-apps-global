# typed: false
# frozen_string_literal: true

class OrgDocsPostVersion < OrgPrincipalRecord
  self.table_name = "org_docs_post_versions"

  include Cms::PostVersionModel

  cms_post_version_model post_class_name: "OrgDocsPost", revision_class_name: "OrgDocsPostRevision",
                         publication_class_name: "OrgDocsPostPublication", media_usage_class_name: "OrgDocsMediaUsage",
                         category_assignment_class_name: "OrgDocsPostVersionCategory",
                         tag_assignment_class_name: "OrgDocsPostVersionTag"
end
