# typed: false
# frozen_string_literal: true

class OrgHelpCategory < OrgPrincipalRecord
  self.table_name = "org_help_categories"

  include Cms::CategoryModel

  cms_category_model category_class_name: "OrgHelpCategory",
                     revision_assignment_class_name: "OrgHelpPostRevisionCategory",
                     version_assignment_class_name: "OrgHelpPostVersionCategory"
end
