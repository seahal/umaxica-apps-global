# typed: false
# frozen_string_literal: true

class ComInfoPostRevision < ComPrincipalRecord
  self.table_name = "com_info_post_revisions"

  include Cms::PostRevisionModel

  cms_post_revision_model post_class_name: "ComInfoPost", revision_class_name: "ComInfoPostRevision",
                          version_class_name: "ComInfoPostVersion", media_usage_class_name: "ComInfoMediaUsage",
                          category_assignment_class_name: "ComInfoPostRevisionCategory",
                          tag_assignment_class_name: "ComInfoPostRevisionTag"
end
