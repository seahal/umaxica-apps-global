# typed: false
# frozen_string_literal: true

class ComDocsPostRevisionTag < ComPrincipalRecord
  self.table_name = "com_docs_post_revision_tags"

  include Cms::TagAssignmentModel

  cms_tag_assignment_model owner_name: :post_revision, owner_class_name: "ComDocsPostRevision",
                           owner_foreign_key: :post_revision_id, owner_inverse: :revision_tags, tag_class_name: "ComDocsTag"
end
