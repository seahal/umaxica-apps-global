# typed: false
# frozen_string_literal: true

class OrgInfoPostVersionTag < OrgPrincipalRecord
  self.table_name = "org_info_post_version_tags"

  include Cms::TagAssignmentModel

  cms_tag_assignment_model owner_name: :post_version, owner_class_name: "OrgInfoPostVersion",
                           owner_foreign_key: :post_version_id, owner_inverse: :version_tags, tag_class_name: "OrgInfoTag"
end
