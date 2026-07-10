# typed: false
# frozen_string_literal: true

class AppInfoTag < AppPrincipalRecord
  self.table_name = "app_info_tags"

  include Cms::TagModel

  cms_tag_model revision_assignment_class_name: "AppInfoPostRevisionTag",
                version_assignment_class_name: "AppInfoPostVersionTag"
end
