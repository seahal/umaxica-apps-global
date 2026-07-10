# typed: false
# frozen_string_literal: true

class AppDocsPost < AppPrincipalRecord
  self.table_name = "app_docs_posts"

  include Cms::PostModel

  cms_post_model revision_class_name: "AppDocsPostRevision", slug_class_name: "AppDocsPostSlug",
                 version_class_name: "AppDocsPostVersion", publication_class_name: "AppDocsPostPublication",
                 media_usage_class_name: "AppDocsMediaUsage"
end
