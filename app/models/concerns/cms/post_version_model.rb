# typed: false
# frozen_string_literal: true

module Cms
  module PostVersionModel
    extend ActiveSupport::Concern
    include PublicId
    include Cms::ImmutableRecord
    include Cms::StructuredBody
    include Cms::OperatorProvenance

    class_methods do
      def cms_post_version_model(post_class_name:, revision_class_name:, publication_class_name:, media_usage_class_name:,
                                 category_assignment_class_name:, tag_assignment_class_name:)
        belongs_to :post, class_name: post_class_name, foreign_key: :post_id, inverse_of: :versions
        belongs_to :post_revision, class_name: revision_class_name, foreign_key: :post_revision_id, inverse_of: :version
        has_many :restored_revisions, class_name: revision_class_name, foreign_key: :restored_from_version_id,
                                      inverse_of: :restored_from_version, dependent: :restrict_with_exception
        has_many :publications, class_name: publication_class_name, foreign_key: :post_version_id,
                                inverse_of: :post_version, dependent: :restrict_with_exception
        has_many :media_usages, class_name: media_usage_class_name, foreign_key: :post_version_id,
                                inverse_of: :post_version, dependent: :restrict_with_exception
        has_one :version_category, class_name: category_assignment_class_name, foreign_key: :post_version_id,
                                   inverse_of: :post_version, dependent: :restrict_with_exception
        has_many :version_tags, class_name: tag_assignment_class_name, foreign_key: :post_version_id,
                                inverse_of: :post_version, dependent: :restrict_with_exception
      end
    end

    included do
      validates :locale, :title, :body, :schema_version, presence: true
      validates :sequence, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :post_id }
      validates :post_revision_id, uniqueness: true
      validate :version_consistency
    end

    private

    def version_consistency
      return unless post.present? && post_revision.present?

      errors.add(:post_revision, "must belong to the same post") if post_revision.post != post
      errors.add(:locale, "must match post and revision") if locale != post.locale || locale != post_revision.locale
    end
  end
end
