# typed: false
# frozen_string_literal: true

class AppHelpPostVersion < AppPrincipalRecord
  self.table_name = "app_help_post_versions"

  include Cms::PostVersionModel

  cms_post_version_model post_class_name: "AppHelpPost", revision_class_name: "AppHelpPostRevision",
                         publication_class_name: "AppHelpPostPublication", media_usage_class_name: "AppHelpMediaUsage",
                         category_assignment_class_name: "AppHelpPostVersionCategory",
                         tag_assignment_class_name: "AppHelpPostVersionTag"
end
