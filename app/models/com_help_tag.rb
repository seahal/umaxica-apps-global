# typed: false
# frozen_string_literal: true

class ComHelpTag < ComPrincipalRecord
  self.table_name = "com_help_tags"

  include Cms::TagModel

  cms_tag_model revision_assignment_class_name: "ComHelpPostRevisionTag",
                version_assignment_class_name: "ComHelpPostVersionTag"
end
