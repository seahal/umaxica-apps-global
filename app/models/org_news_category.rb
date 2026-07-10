# typed: false
# frozen_string_literal: true

class OrgNewsCategory < OrgPrincipalRecord
  self.table_name = "org_news_categories"

  include Cms::CategoryModel

  cms_category_model category_class_name: "OrgNewsCategory",
                     revision_assignment_class_name: "OrgNewsPostRevisionCategory",
                     version_assignment_class_name: "OrgNewsPostVersionCategory"
end
