# typed: false
# frozen_string_literal: true

module Cms
  module PostPublicationModel
    extend ActiveSupport::Concern
    include PublicId
    include Cms::PublicationPredicates
    include Cms::OperatorProvenance

    class_methods do
      def cms_post_publication_model(post_class_name:, version_class_name:)
        belongs_to :post, class_name: post_class_name, foreign_key: :post_id, inverse_of: :publications
        belongs_to :post_version, class_name: version_class_name, foreign_key: :post_version_id,
                                  inverse_of: :publications
      end
    end

    included do
      validates :effective_from, presence: true
      validate :publication_consistency
      scope :uncancelled, -> { where(cancelled_at: nil) }
      scope :scheduled_at, ->(time) { uncancelled.where("effective_from > ?", time) }
      scope :effective_at, ->(time) { uncancelled.where("effective_from <= ? AND (effective_until IS NULL OR effective_until > ?)", time, time) }
      scope :ended_at, ->(time) { where("cancelled_at IS NOT NULL OR effective_until <= ?", time) }
    end

    private

    def publication_consistency
      errors.add(:post_version, "must belong to the same post") if post.present? && post_version.present? && post_version.post != post
      errors.add(:effective_until, "must be after effective_from") if effective_until.present? && effective_from.present? && effective_until <= effective_from
      errors.add(:base, "cancellation and termination are mutually exclusive") if cancelled_at.present? && terminated_at.present?
      errors.add(:cancellation_reason, "must be present") if cancelled_at.present? && cancellation_reason.blank?
      errors.add(:cancelled_at, "must precede effective_from") if cancelled_at.present? && effective_from.present? && cancelled_at >= effective_from
      errors.add(:termination_reason, "must be present") if terminated_at.present? && termination_reason.blank?
      errors.add(:terminated_at, "must not precede effective_from") if terminated_at.present? && effective_from.present? && terminated_at < effective_from
      errors.add(:effective_until, "must equal terminated_at") if terminated_at.present? && effective_until != terminated_at
    end
  end
end
