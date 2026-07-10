# typed: false
# frozen_string_literal: true

class AppNewsPost < AppPrincipalRecord
  self.table_name = "app_news_posts"

  include Cms::PostModel

  cms_post_model revision_class_name: "AppNewsPostRevision", slug_class_name: "AppNewsPostSlug",
                 version_class_name: "AppNewsPostVersion", publication_class_name: "AppNewsPostPublication",
                 media_usage_class_name: "AppNewsMediaUsage"
end
