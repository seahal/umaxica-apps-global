# typed: false
# frozen_string_literal: true

class AppInfoPost < AppPrincipalRecord
  self.table_name = "app_info_posts"

  include Cms::PostModel

  cms_post_model revision_class_name: "AppInfoPostRevision", slug_class_name: "AppInfoPostSlug",
                 version_class_name: "AppInfoPostVersion", publication_class_name: "AppInfoPostPublication",
                 media_usage_class_name: "AppInfoMediaUsage"
end
