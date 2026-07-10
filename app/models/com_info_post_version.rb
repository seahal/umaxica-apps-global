# typed: false
# frozen_string_literal: true

class ComInfoPostVersion < ComPrincipalRecord
  self.table_name = "com_info_post_versions"

  include Cms::PostVersionModel

  cms_post_version_model post_class_name: "ComInfoPost", revision_class_name: "ComInfoPostRevision",
                         publication_class_name: "ComInfoPostPublication", media_usage_class_name: "ComInfoMediaUsage",
                         category_assignment_class_name: "ComInfoPostVersionCategory",
                         tag_assignment_class_name: "ComInfoPostVersionTag"
end
