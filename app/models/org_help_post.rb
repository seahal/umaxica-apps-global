# typed: false
# frozen_string_literal: true

class OrgHelpPost < OrgPrincipalRecord
  self.table_name = "org_help_posts"

  include Cms::PostModel

  cms_post_model revision_class_name: "OrgHelpPostRevision", slug_class_name: "OrgHelpPostSlug",
                 version_class_name: "OrgHelpPostVersion", publication_class_name: "OrgHelpPostPublication",
                 media_usage_class_name: "OrgHelpMediaUsage"
end
