# typed: false
# frozen_string_literal: true

class OrgHelpPostRevisionTag < OrgPrincipalRecord
  self.table_name = "org_help_post_revision_tags"

  include Cms::TagAssignmentModel

  cms_tag_assignment_model owner_name: :post_revision, owner_class_name: "OrgHelpPostRevision",
                           owner_foreign_key: :post_revision_id, owner_inverse: :revision_tags, tag_class_name: "OrgHelpTag"
end
