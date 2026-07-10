# typed: false
# frozen_string_literal: true

module Cms
  module PostRevisionModel
    extend ActiveSupport::Concern
    include PublicId
    include Cms::ImmutableRecord
    include Cms::StructuredBody
    include Cms::OperatorProvenance

    class_methods do
      def cms_post_revision_model(post_class_name:, revision_class_name:, version_class_name:, media_usage_class_name:,
                                  category_assignment_class_name:, tag_assignment_class_name:)
        belongs_to :post, class_name: post_class_name, foreign_key: :post_id, inverse_of: :revisions
        belongs_to :restored_from_revision, class_name: revision_class_name, foreign_key: :restored_from_revision_id,
                                            inverse_of: :restored_revisions, optional: true
        belongs_to :restored_from_version, class_name: version_class_name, foreign_key: :restored_from_version_id,
                                           inverse_of: :restored_revisions, optional: true
        has_many :restored_revisions, class_name: revision_class_name, foreign_key: :restored_from_revision_id,
                                      inverse_of: :restored_from_revision, dependent: :restrict_with_exception
        has_one :version, class_name: version_class_name, foreign_key: :post_revision_id, inverse_of: :post_revision,
                          dependent: :restrict_with_exception
        has_one :current_for_post, class_name: post_class_name, foreign_key: :current_revision_id,
                                   inverse_of: :current_revision, dependent: :restrict_with_exception
        has_many :media_usages, class_name: media_usage_class_name, foreign_key: :post_revision_id,
                                inverse_of: :post_revision, dependent: :restrict_with_exception
        has_one :revision_category, class_name: category_assignment_class_name, foreign_key: :post_revision_id,
                                    inverse_of: :post_revision, dependent: :restrict_with_exception
        has_many :revision_tags, class_name: tag_assignment_class_name, foreign_key: :post_revision_id,
                                 inverse_of: :post_revision, dependent: :restrict_with_exception
      end
    end

    included do
      validates :locale, :title, :body, :schema_version, presence: true
      validates :sequence, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :post_id }
      validate :revision_consistency
    end

    private

    def revision_consistency
      errors.add(:locale, "must match post") if post.present? && locale != post.locale
      unless Cms::OwnershipRules.at_most_one?(restored_from_revision, restored_from_version)
        errors.add(:base, "restoration source must be unique")
      end
      [restored_from_revision, restored_from_version].compact.each do |source|
        errors.add(:base, "restoration source must belong to the same post") if source.post != post
      end
    end
  end
end
