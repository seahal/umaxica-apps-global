# typed: false
# frozen_string_literal: true

class ComHelpPostVersionCategory < ComPrincipalRecord
  self.table_name = "com_help_post_version_categories"

  include Cms::CategoryAssignmentModel

  cms_category_assignment_model owner_name: :post_version, owner_class_name: "ComHelpPostVersion",
                                owner_foreign_key: :post_version_id, owner_inverse: :version_category,
                                category_class_name: "ComHelpCategory"
end
