# typed: false
# frozen_string_literal: true

class ComInfoPost < ComPrincipalRecord
  self.table_name = "com_info_posts"

  include Cms::PostModel

  cms_post_model revision_class_name: "ComInfoPostRevision", slug_class_name: "ComInfoPostSlug",
                 version_class_name: "ComInfoPostVersion", publication_class_name: "ComInfoPostPublication",
                 media_usage_class_name: "ComInfoMediaUsage"
end
