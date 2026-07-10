# typed: false
# frozen_string_literal: true

class OrgHelpPostVersion < OrgPrincipalRecord
  self.table_name = "org_help_post_versions"

  include Cms::PostVersionModel

  cms_post_version_model post_class_name: "OrgHelpPost", revision_class_name: "OrgHelpPostRevision",
                         publication_class_name: "OrgHelpPostPublication", media_usage_class_name: "OrgHelpMediaUsage",
                         category_assignment_class_name: "OrgHelpPostVersionCategory",
                         tag_assignment_class_name: "OrgHelpPostVersionTag"
end
