# typed: false
# frozen_string_literal: true

class ComNewsPostRevisionCategory < ComPrincipalRecord
  self.table_name = "com_news_post_revision_categories"

  include Cms::CategoryAssignmentModel

  cms_category_assignment_model owner_name: :post_revision, owner_class_name: "ComNewsPostRevision",
                                owner_foreign_key: :post_revision_id, owner_inverse: :revision_category,
                                category_class_name: "ComNewsCategory"
end
