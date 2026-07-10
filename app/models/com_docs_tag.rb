# typed: false
# frozen_string_literal: true

class ComDocsTag < ComPrincipalRecord
  self.table_name = "com_docs_tags"

  include Cms::TagModel

  cms_tag_model revision_assignment_class_name: "ComDocsPostRevisionTag",
                version_assignment_class_name: "ComDocsPostVersionTag"
end
