# typed: false
# frozen_string_literal: true

class ComDocsPost < ComPrincipalRecord
  self.table_name = "com_docs_posts"

  include Cms::PostModel

  cms_post_model revision_class_name: "ComDocsPostRevision", slug_class_name: "ComDocsPostSlug",
                 version_class_name: "ComDocsPostVersion", publication_class_name: "ComDocsPostPublication",
                 media_usage_class_name: "ComDocsMediaUsage"
end
