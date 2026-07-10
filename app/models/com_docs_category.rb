# typed: false
# frozen_string_literal: true

class ComDocsCategory < ComPrincipalRecord
  self.table_name = "com_docs_categories"

  include Cms::CategoryModel

  cms_category_model category_class_name: "ComDocsCategory",
                     revision_assignment_class_name: "ComDocsPostRevisionCategory",
                     version_assignment_class_name: "ComDocsPostVersionCategory"
end
