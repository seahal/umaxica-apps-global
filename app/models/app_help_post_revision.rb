# typed: false
# frozen_string_literal: true

class AppHelpPostRevision < AppPrincipalRecord
  self.table_name = "app_help_post_revisions"

  include Cms::PostRevisionModel

  cms_post_revision_model post_class_name: "AppHelpPost", revision_class_name: "AppHelpPostRevision",
                          version_class_name: "AppHelpPostVersion", media_usage_class_name: "AppHelpMediaUsage",
                          category_assignment_class_name: "AppHelpPostRevisionCategory",
                          tag_assignment_class_name: "AppHelpPostRevisionTag"
end
