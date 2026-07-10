# typed: false
# frozen_string_literal: true

class ComHelpPostVersion < ComPrincipalRecord
  self.table_name = "com_help_post_versions"

  include Cms::PostVersionModel

  cms_post_version_model post_class_name: "ComHelpPost", revision_class_name: "ComHelpPostRevision",
                         publication_class_name: "ComHelpPostPublication", media_usage_class_name: "ComHelpMediaUsage",
                         category_assignment_class_name: "ComHelpPostVersionCategory",
                         tag_assignment_class_name: "ComHelpPostVersionTag"
end
