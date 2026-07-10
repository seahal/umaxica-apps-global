# typed: false
# frozen_string_literal: true

class ComHelpCategory < ComPrincipalRecord
  self.table_name = "com_help_categories"

  include Cms::CategoryModel

  cms_category_model category_class_name: "ComHelpCategory",
                     revision_assignment_class_name: "ComHelpPostRevisionCategory",
                     version_assignment_class_name: "ComHelpPostVersionCategory"
end
