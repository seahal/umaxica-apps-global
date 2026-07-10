# typed: false
# frozen_string_literal: true

class OrgDocsPostRevisionTag < OrgPrincipalRecord
  self.table_name = "org_docs_post_revision_tags"

  include Cms::TagAssignmentModel

  cms_tag_assignment_model owner_name: :post_revision, owner_class_name: "OrgDocsPostRevision",
                           owner_foreign_key: :post_revision_id, owner_inverse: :revision_tags, tag_class_name: "OrgDocsTag"
end
