# typed: false
# frozen_string_literal: true

class AppDocsTag < AppPrincipalRecord
  self.table_name = "app_docs_tags"

  include Cms::TagModel

  cms_tag_model revision_assignment_class_name: "AppDocsPostRevisionTag",
                version_assignment_class_name: "AppDocsPostVersionTag"
end
