# typed: false
# frozen_string_literal: true

class ComHelpPostRevision < ComPrincipalRecord
  self.table_name = "com_help_post_revisions"

  include Cms::PostRevisionModel

  cms_post_revision_model post_class_name: "ComHelpPost", revision_class_name: "ComHelpPostRevision",
                          version_class_name: "ComHelpPostVersion", media_usage_class_name: "ComHelpMediaUsage",
                          category_assignment_class_name: "ComHelpPostRevisionCategory",
                          tag_assignment_class_name: "ComHelpPostRevisionTag"
end
