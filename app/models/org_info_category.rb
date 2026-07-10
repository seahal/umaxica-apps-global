# typed: false
# frozen_string_literal: true

class OrgInfoCategory < OrgPrincipalRecord
  self.table_name = "org_info_categories"

  include Cms::CategoryModel

  cms_category_model category_class_name: "OrgInfoCategory",
                     revision_assignment_class_name: "OrgInfoPostRevisionCategory",
                     version_assignment_class_name: "OrgInfoPostVersionCategory"
end
