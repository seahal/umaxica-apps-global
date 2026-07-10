# typed: false
# frozen_string_literal: true

class AppNewsCategory < AppPrincipalRecord
  self.table_name = "app_news_categories"

  include Cms::CategoryModel

  cms_category_model category_class_name: "AppNewsCategory",
                     revision_assignment_class_name: "AppNewsPostRevisionCategory",
                     version_assignment_class_name: "AppNewsPostVersionCategory"
end
