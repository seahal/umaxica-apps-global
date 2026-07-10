# typed: false
# frozen_string_literal: true

class ComHelpPostSlug < ComPrincipalRecord
  self.table_name = "com_help_post_slugs"

  include Cms::PostSlugModel

  cms_post_slug_model post_class_name: "ComHelpPost"
end
