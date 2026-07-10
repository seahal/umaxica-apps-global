# typed: false
# frozen_string_literal: true

class AppDocsCategory < AppPrincipalRecord
  self.table_name = "app_docs_categories"

  include Cms::CategoryModel

  cms_category_model category_class_name: "AppDocsCategory",
                     revision_assignment_class_name: "AppDocsPostRevisionCategory",
                     version_assignment_class_name: "AppDocsPostVersionCategory"
end
