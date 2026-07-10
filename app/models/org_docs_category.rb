# typed: false
# frozen_string_literal: true

class OrgDocsCategory < OrgPrincipalRecord
  self.table_name = "org_docs_categories"

  include Cms::CategoryModel

  cms_category_model category_class_name: "OrgDocsCategory",
                     revision_assignment_class_name: "OrgDocsPostRevisionCategory",
                     version_assignment_class_name: "OrgDocsPostVersionCategory"
end
