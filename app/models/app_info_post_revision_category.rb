# typed: false
# frozen_string_literal: true

class AppInfoPostRevisionCategory < AppPrincipalRecord
  self.table_name = "app_info_post_revision_categories"

  include Cms::CategoryAssignmentModel

  cms_category_assignment_model owner_name: :post_revision, owner_class_name: "AppInfoPostRevision",
                                owner_foreign_key: :post_revision_id, owner_inverse: :revision_category,
                                category_class_name: "AppInfoCategory"
end
