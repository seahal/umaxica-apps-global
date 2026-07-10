# typed: false
# frozen_string_literal: true

class ComInfoPostSlug < ComPrincipalRecord
  self.table_name = "com_info_post_slugs"

  include Cms::PostSlugModel

  cms_post_slug_model post_class_name: "ComInfoPost"
end
