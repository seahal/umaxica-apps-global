# typed: false
# frozen_string_literal: true

class ComHelpPost < ComPrincipalRecord
  self.table_name = "com_help_posts"

  include Cms::PostModel

  cms_post_model revision_class_name: "ComHelpPostRevision", slug_class_name: "ComHelpPostSlug",
                 version_class_name: "ComHelpPostVersion", publication_class_name: "ComHelpPostPublication",
                 media_usage_class_name: "ComHelpMediaUsage"
end
