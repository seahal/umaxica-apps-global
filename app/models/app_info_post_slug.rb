# typed: false
# frozen_string_literal: true

class AppInfoPostSlug < AppPrincipalRecord
  self.table_name = "app_info_post_slugs"

  include Cms::PostSlugModel

  cms_post_slug_model post_class_name: "AppInfoPost"
end
