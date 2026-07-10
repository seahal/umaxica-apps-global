# typed: false
# frozen_string_literal: true

class ComNewsPostVersion < ComPrincipalRecord
  self.table_name = "com_news_post_versions"

  include Cms::PostVersionModel

  cms_post_version_model post_class_name: "ComNewsPost", revision_class_name: "ComNewsPostRevision",
                         publication_class_name: "ComNewsPostPublication", media_usage_class_name: "ComNewsMediaUsage",
                         category_assignment_class_name: "ComNewsPostVersionCategory",
                         tag_assignment_class_name: "ComNewsPostVersionTag"
end
