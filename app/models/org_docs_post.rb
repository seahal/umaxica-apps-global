# typed: false
# frozen_string_literal: true

class OrgDocsPost < OrgPrincipalRecord
  self.table_name = "org_docs_posts"

  include Cms::PostModel

  cms_post_model revision_class_name: "OrgDocsPostRevision", slug_class_name: "OrgDocsPostSlug",
                 version_class_name: "OrgDocsPostVersion", publication_class_name: "OrgDocsPostPublication",
                 media_usage_class_name: "OrgDocsMediaUsage"
end
