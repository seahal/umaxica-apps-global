# typed: false
# frozen_string_literal: true

require "set"

module CmsCategoryModel
  extend ActiveSupport::Concern
  include Cms::TaxonomyTermModel

  class_methods do
    def cms_category_model(category_class_name:, revision_assignment_class_name:, version_assignment_class_name:)
      belongs_to :parent, class_name: category_class_name, inverse_of: :children, optional: true
      has_many :children, class_name: category_class_name, foreign_key: :parent_id, inverse_of: :parent,
                          dependent: :restrict_with_exception
      has_many :revision_assignments, class_name: revision_assignment_class_name, foreign_key: :category_id,
                                      inverse_of: :category, dependent: :restrict_with_exception
      has_many :version_assignments, class_name: version_assignment_class_name, foreign_key: :category_id,
                                     inverse_of: :category, dependent: :restrict_with_exception
    end
  end

  included do
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validate :category_hierarchy_is_valid
  end

  private

  def category_hierarchy_is_valid
    errors.add(:parent, "cannot be self") if parent.equal?(self) || (id.present? && parent_id == id)
    errors.add(:parent, "must have the same locale") if parent.present? && parent.locale != locale
    visited = Set.new
    ancestor = parent
    while ancestor
      key = ancestor.id || ancestor.object_id
      if ancestor.equal?(self) || visited.include?(key)
        errors.add(:parent, "creates a cycle")
        break
      end
      visited << key
      ancestor = ancestor.parent
    end
  end
end

module Cms
  CategoryModel = ::CmsCategoryModel
end
