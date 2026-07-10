# typed: false
# frozen_string_literal: true

class AppDocsPostSlug < AppPrincipalRecord
  self.table_name = "app_docs_post_slugs"

  include Cms::PostSlugModel

  cms_post_slug_model post_class_name: "AppDocsPost"
end
