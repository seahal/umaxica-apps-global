# typed: false
# frozen_string_literal: true

module CmsTagAssignmentModel
  extend ActiveSupport::Concern
  include Cms::TaxonomyAssignmentModel

  class_methods do
    def cms_tag_assignment_model(owner_name:, owner_class_name:, owner_foreign_key:, owner_inverse:, tag_class_name:)
      belongs_to owner_name, class_name: owner_class_name, foreign_key: owner_foreign_key, inverse_of: owner_inverse
      belongs_to :tag, class_name: tag_class_name,
                       inverse_of: (owner_name == :post_revision) ? :revision_assignments : :version_assignments
      validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, uniqueness: { scope: owner_foreign_key }
      validates :tag_id, uniqueness: { scope: owner_foreign_key }
      validate do
        owner = public_send(owner_name)
        errors.add(:locale, "must match owner and tag") if owner.present? && tag.present? &&
          (locale != owner.locale || locale != tag.locale)
      end
    end
  end
end

module Cms
  TagAssignmentModel = ::CmsTagAssignmentModel
end
