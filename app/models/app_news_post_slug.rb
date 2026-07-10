# typed: false
# frozen_string_literal: true

class AppNewsPostSlug < AppPrincipalRecord
  self.table_name = "app_news_post_slugs"

  include Cms::PostSlugModel

  cms_post_slug_model post_class_name: "AppNewsPost"
end
