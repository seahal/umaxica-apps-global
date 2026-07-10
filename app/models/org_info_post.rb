# typed: false
# frozen_string_literal: true

class OrgInfoPost < OrgPrincipalRecord
  self.table_name = "org_info_posts"

  include Cms::PostModel

  cms_post_model revision_class_name: "OrgInfoPostRevision", slug_class_name: "OrgInfoPostSlug",
                 version_class_name: "OrgInfoPostVersion", publication_class_name: "OrgInfoPostPublication",
                 media_usage_class_name: "OrgInfoMediaUsage"
end
