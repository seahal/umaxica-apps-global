# typed: false
# frozen_string_literal: true

class OrgInfoPostRevision < OrgPrincipalRecord
  self.table_name = "org_info_post_revisions"

  include Cms::PostRevisionModel

  cms_post_revision_model post_class_name: "OrgInfoPost", revision_class_name: "OrgInfoPostRevision",
                          version_class_name: "OrgInfoPostVersion", media_usage_class_name: "OrgInfoMediaUsage",
                          category_assignment_class_name: "OrgInfoPostRevisionCategory",
                          tag_assignment_class_name: "OrgInfoPostRevisionTag"
end
