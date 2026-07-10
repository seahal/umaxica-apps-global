# typed: false
# frozen_string_literal: true

class AppHelpCategory < AppPrincipalRecord
  self.table_name = "app_help_categories"

  include Cms::CategoryModel

  cms_category_model category_class_name: "AppHelpCategory",
                     revision_assignment_class_name: "AppHelpPostRevisionCategory",
                     version_assignment_class_name: "AppHelpPostVersionCategory"
end
