# typed: false
# frozen_string_literal: true

class ComInfoCategory < ComPrincipalRecord
  self.table_name = "com_info_categories"

  include Cms::CategoryModel

  cms_category_model category_class_name: "ComInfoCategory",
                     revision_assignment_class_name: "ComInfoPostRevisionCategory",
                     version_assignment_class_name: "ComInfoPostVersionCategory"
end
