# typed: false
# frozen_string_literal: true

class OrgNewsTag < OrgPrincipalRecord
  self.table_name = "org_news_tags"

  include Cms::TagModel

  cms_tag_model revision_assignment_class_name: "OrgNewsPostRevisionTag",
                version_assignment_class_name: "OrgNewsPostVersionTag"
end
