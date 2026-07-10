# typed: false
# frozen_string_literal: true

class ComNewsTag < ComPrincipalRecord
  self.table_name = "com_news_tags"

  include Cms::TagModel

  cms_tag_model revision_assignment_class_name: "ComNewsPostRevisionTag",
                version_assignment_class_name: "ComNewsPostVersionTag"
end
