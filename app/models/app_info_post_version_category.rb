# typed: false
# frozen_string_literal: true

class AppInfoPostVersionCategory < AppPrincipalRecord
  self.table_name = "app_info_post_version_categories"

  include Cms::CategoryAssignmentModel

  cms_category_assignment_model owner_name: :post_version, owner_class_name: "AppInfoPostVersion",
                                owner_foreign_key: :post_version_id, owner_inverse: :version_category,
                                category_class_name: "AppInfoCategory"
end
