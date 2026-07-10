# typed: false
# frozen_string_literal: true

class OrgHelpPostRevision < OrgPrincipalRecord
  self.table_name = "org_help_post_revisions"

  include Cms::PostRevisionModel

  cms_post_revision_model post_class_name: "OrgHelpPost", revision_class_name: "OrgHelpPostRevision",
                          version_class_name: "OrgHelpPostVersion", media_usage_class_name: "OrgHelpMediaUsage",
                          category_assignment_class_name: "OrgHelpPostRevisionCategory",
                          tag_assignment_class_name: "OrgHelpPostRevisionTag"
end
