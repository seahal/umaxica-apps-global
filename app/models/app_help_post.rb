# typed: false
# frozen_string_literal: true

class AppHelpPost < AppPrincipalRecord
  self.table_name = "app_help_posts"

  include Cms::PostModel

  cms_post_model revision_class_name: "AppHelpPostRevision", slug_class_name: "AppHelpPostSlug",
                 version_class_name: "AppHelpPostVersion", publication_class_name: "AppHelpPostPublication",
                 media_usage_class_name: "AppHelpMediaUsage"
end
