# typed: false
# frozen_string_literal: true

class AppHelpTag < AppPrincipalRecord
  self.table_name = "app_help_tags"

  include Cms::TagModel

  cms_tag_model revision_assignment_class_name: "AppHelpPostRevisionTag",
                version_assignment_class_name: "AppHelpPostVersionTag"
end
