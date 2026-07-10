# typed: false
# frozen_string_literal: true

class OrgNewsPostRevision < OrgPrincipalRecord
  self.table_name = "org_news_post_revisions"

  include Cms::PostRevisionModel

  cms_post_revision_model post_class_name: "OrgNewsPost", revision_class_name: "OrgNewsPostRevision",
                          version_class_name: "OrgNewsPostVersion", media_usage_class_name: "OrgNewsMediaUsage",
                          category_assignment_class_name: "OrgNewsPostRevisionCategory",
                          tag_assignment_class_name: "OrgNewsPostRevisionTag"
end
