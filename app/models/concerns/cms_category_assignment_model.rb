# typed: false
# frozen_string_literal: true

module CmsCategoryAssignmentModel
  extend ActiveSupport::Concern
  include Cms::TaxonomyAssignmentModel

  class_methods do
    def cms_category_assignment_model(owner_name:, owner_class_name:, owner_foreign_key:, owner_inverse:, category_class_name:)
      belongs_to owner_name, class_name: owner_class_name, foreign_key: owner_foreign_key, inverse_of: owner_inverse
      belongs_to :category, class_name: category_class_name,
                            inverse_of: (owner_name == :post_revision) ? :revision_assignments : :version_assignments
      validates owner_foreign_key, uniqueness: true
      validate do
        owner = public_send(owner_name)
        errors.add(:locale, "must match owner and category") if owner.present? && category.present? &&
          (locale != owner.locale || locale != category.locale)
      end
    end
  end
end

module Cms
  CategoryAssignmentModel = ::CmsCategoryAssignmentModel
end
