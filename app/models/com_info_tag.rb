# typed: false
# frozen_string_literal: true

class ComInfoTag < ComPrincipalRecord
  self.table_name = "com_info_tags"

  include Cms::TagModel

  cms_tag_model revision_assignment_class_name: "ComInfoPostRevisionTag",
                version_assignment_class_name: "ComInfoPostVersionTag"
end
