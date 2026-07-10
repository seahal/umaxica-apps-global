# typed: false
# frozen_string_literal: true

class OrgInfoPostRevisionCategory < OrgPrincipalRecord
  self.table_name = "org_info_post_revision_categories"

  include Cms::CategoryAssignmentModel

  cms_category_assignment_model owner_name: :post_revision, owner_class_name: "OrgInfoPostRevision",
                                owner_foreign_key: :post_revision_id, owner_inverse: :revision_category,
                                category_class_name: "OrgInfoCategory"
end
