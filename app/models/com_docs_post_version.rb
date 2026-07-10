# typed: false
# frozen_string_literal: true

class ComDocsPostVersion < ComPrincipalRecord
  self.table_name = "com_docs_post_versions"

  include Cms::PostVersionModel

  cms_post_version_model post_class_name: "ComDocsPost", revision_class_name: "ComDocsPostRevision",
                         publication_class_name: "ComDocsPostPublication", media_usage_class_name: "ComDocsMediaUsage",
                         category_assignment_class_name: "ComDocsPostVersionCategory",
                         tag_assignment_class_name: "ComDocsPostVersionTag"
end
