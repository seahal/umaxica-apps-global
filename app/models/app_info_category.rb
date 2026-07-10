# typed: false
# frozen_string_literal: true

class AppInfoCategory < AppPrincipalRecord
  self.table_name = "app_info_categories"

  include Cms::CategoryModel

  cms_category_model category_class_name: "AppInfoCategory",
                     revision_assignment_class_name: "AppInfoPostRevisionCategory",
                     version_assignment_class_name: "AppInfoPostVersionCategory"
end
