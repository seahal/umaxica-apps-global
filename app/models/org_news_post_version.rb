# typed: false
# frozen_string_literal: true

class OrgNewsPostVersion < OrgPrincipalRecord
  self.table_name = "org_news_post_versions"

  include Cms::PostVersionModel

  cms_post_version_model post_class_name: "OrgNewsPost", revision_class_name: "OrgNewsPostRevision",
                         publication_class_name: "OrgNewsPostPublication", media_usage_class_name: "OrgNewsMediaUsage",
                         category_assignment_class_name: "OrgNewsPostVersionCategory",
                         tag_assignment_class_name: "OrgNewsPostVersionTag"
end
