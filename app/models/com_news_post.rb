# typed: false
# frozen_string_literal: true

class ComNewsPost < ComPrincipalRecord
  self.table_name = "com_news_posts"

  include Cms::PostModel

  cms_post_model revision_class_name: "ComNewsPostRevision", slug_class_name: "ComNewsPostSlug",
                 version_class_name: "ComNewsPostVersion", publication_class_name: "ComNewsPostPublication",
                 media_usage_class_name: "ComNewsMediaUsage"
end
