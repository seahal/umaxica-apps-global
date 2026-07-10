# typed: false
# frozen_string_literal: true

class ComDocsPostSlug < ComPrincipalRecord
  self.table_name = "com_docs_post_slugs"

  include Cms::PostSlugModel

  cms_post_slug_model post_class_name: "ComDocsPost"
end
