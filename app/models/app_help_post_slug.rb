# typed: false
# frozen_string_literal: true

class AppHelpPostSlug < AppPrincipalRecord
  self.table_name = "app_help_post_slugs"

  include Cms::PostSlugModel

  cms_post_slug_model post_class_name: "AppHelpPost"
end
