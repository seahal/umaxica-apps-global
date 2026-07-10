# typed: false
# frozen_string_literal: true

class OrgNewsPost < OrgPrincipalRecord
  self.table_name = "org_news_posts"

  include Cms::PostModel

  cms_post_model revision_class_name: "OrgNewsPostRevision", slug_class_name: "OrgNewsPostSlug",
                 version_class_name: "OrgNewsPostVersion", publication_class_name: "OrgNewsPostPublication",
                 media_usage_class_name: "OrgNewsMediaUsage"
end
