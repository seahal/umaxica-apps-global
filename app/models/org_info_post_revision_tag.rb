# typed: false
# frozen_string_literal: true

class OrgInfoPostRevisionTag < OrgPrincipalRecord
  self.table_name = "org_info_post_revision_tags"

  include Cms::TagAssignmentModel

  cms_tag_assignment_model owner_name: :post_revision, owner_class_name: "OrgInfoPostRevision",
                           owner_foreign_key: :post_revision_id, owner_inverse: :revision_tags, tag_class_name: "OrgInfoTag"
end
