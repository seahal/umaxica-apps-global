# typed: false
# frozen_string_literal: true

module CmsMediaUsageModel
  extend ActiveSupport::Concern
  include PublicId
  include Cms::ImmutableRecord

  class_methods do
    def cms_media_usage_model(media_file_class_name:, post_class_name:, revision_class_name:, version_class_name:)
      belongs_to :media_file, class_name: media_file_class_name, foreign_key: :media_file_id,
                              inverse_of: :media_usages
      belongs_to :post, class_name: post_class_name, foreign_key: :post_id, inverse_of: :media_usages
      belongs_to :post_revision, class_name: revision_class_name, foreign_key: :post_revision_id,
                                 inverse_of: :media_usages, optional: true
      belongs_to :post_version, class_name: version_class_name, foreign_key: :post_version_id,
                                inverse_of: :media_usages, optional: true
    end
  end

  included do
    validates :role, presence: true
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validate :usage_consistency
  end

  private

  def usage_consistency
    errors.add(:base, "must have exactly one owner") unless Cms::OwnershipRules.exactly_one?(post_revision, post_version)
    errors.add(:post_revision, "must belong to post") if post_revision.present? && post_revision.post != post
    errors.add(:post_version, "must belong to post") if post_version.present? && post_version.post != post
    errors.add(:media_file, "must not be archived") if new_record? && media_file&.archived?
    errors.add(:presentation_metadata, "must be an object") if presentation_metadata.present? && !presentation_metadata.is_a?(Hash)
    errors.add(:field_path, "or block_path must be present") if field_path.blank? && block_path.blank?
  end
end

module Cms
  MediaUsageModel = ::CmsMediaUsageModel
end
