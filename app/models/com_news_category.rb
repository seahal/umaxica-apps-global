# typed: false
# frozen_string_literal: true

class ComNewsCategory < ComPrincipalRecord
  self.table_name = "com_news_categories"

  include Cms::CategoryModel

  cms_category_model category_class_name: "ComNewsCategory",
                     revision_assignment_class_name: "ComNewsPostRevisionCategory",
                     version_assignment_class_name: "ComNewsPostVersionCategory"
end
