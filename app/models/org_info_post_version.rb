# typed: false
# frozen_string_literal: true

class OrgInfoPostVersion < OrgPrincipalRecord
  self.table_name = "org_info_post_versions"

  include Cms::PostVersionModel

  cms_post_version_model post_class_name: "OrgInfoPost", revision_class_name: "OrgInfoPostRevision",
                         publication_class_name: "OrgInfoPostPublication", media_usage_class_name: "OrgInfoMediaUsage",
                         category_assignment_class_name: "OrgInfoPostVersionCategory",
                         tag_assignment_class_name: "OrgInfoPostVersionTag"
end
