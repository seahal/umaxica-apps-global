# typed: false
# frozen_string_literal: true

class OrgHelpTag < OrgPrincipalRecord
  self.table_name = "org_help_tags"

  include Cms::TagModel

  cms_tag_model revision_assignment_class_name: "OrgHelpPostRevisionTag",
                version_assignment_class_name: "OrgHelpPostVersionTag"
end
