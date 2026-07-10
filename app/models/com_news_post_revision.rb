# typed: false
# frozen_string_literal: true

class ComNewsPostRevision < ComPrincipalRecord
  self.table_name = "com_news_post_revisions"

  include Cms::PostRevisionModel

  cms_post_revision_model post_class_name: "ComNewsPost", revision_class_name: "ComNewsPostRevision",
                          version_class_name: "ComNewsPostVersion", media_usage_class_name: "ComNewsMediaUsage",
                          category_assignment_class_name: "ComNewsPostRevisionCategory",
                          tag_assignment_class_name: "ComNewsPostRevisionTag"
end
