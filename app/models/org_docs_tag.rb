# typed: false
# frozen_string_literal: true

class OrgDocsTag < OrgPrincipalRecord
  self.table_name = "org_docs_tags"

  include Cms::TagModel

  cms_tag_model revision_assignment_class_name: "OrgDocsPostRevisionTag",
                version_assignment_class_name: "OrgDocsPostVersionTag"
end
