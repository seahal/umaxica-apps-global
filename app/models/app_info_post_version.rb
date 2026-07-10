# typed: false
# frozen_string_literal: true

class AppInfoPostVersion < AppPrincipalRecord
  self.table_name = "app_info_post_versions"

  include Cms::PostVersionModel

  cms_post_version_model post_class_name: "AppInfoPost", revision_class_name: "AppInfoPostRevision",
                         publication_class_name: "AppInfoPostPublication", media_usage_class_name: "AppInfoMediaUsage",
                         category_assignment_class_name: "AppInfoPostVersionCategory",
                         tag_assignment_class_name: "AppInfoPostVersionTag"
end
