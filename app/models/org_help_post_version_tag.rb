# typed: false
# frozen_string_literal: true

class OrgHelpPostVersionTag < OrgPrincipalRecord
  self.table_name = "org_help_post_version_tags"

  include Cms::TagAssignmentModel

  cms_tag_assignment_model owner_name: :post_version, owner_class_name: "OrgHelpPostVersion",
                           owner_foreign_key: :post_version_id, owner_inverse: :version_tags, tag_class_name: "OrgHelpTag"
end
