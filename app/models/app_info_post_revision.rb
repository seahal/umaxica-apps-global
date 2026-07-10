# typed: false
# frozen_string_literal: true

class AppInfoPostRevision < AppPrincipalRecord
  self.table_name = "app_info_post_revisions"

  include Cms::PostRevisionModel

  cms_post_revision_model post_class_name: "AppInfoPost", revision_class_name: "AppInfoPostRevision",
                          version_class_name: "AppInfoPostVersion", media_usage_class_name: "AppInfoMediaUsage",
                          category_assignment_class_name: "AppInfoPostRevisionCategory",
                          tag_assignment_class_name: "AppInfoPostRevisionTag"
end
