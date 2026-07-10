# typed: false
# frozen_string_literal: true

class OrgInfoTag < OrgPrincipalRecord
  self.table_name = "org_info_tags"

  include Cms::TagModel

  cms_tag_model revision_assignment_class_name: "OrgInfoPostRevisionTag",
                version_assignment_class_name: "OrgInfoPostVersionTag"
end
