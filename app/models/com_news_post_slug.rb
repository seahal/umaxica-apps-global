# typed: false
# frozen_string_literal: true

class ComNewsPostSlug < ComPrincipalRecord
  self.table_name = "com_news_post_slugs"

  include Cms::PostSlugModel

  cms_post_slug_model post_class_name: "ComNewsPost"
end
