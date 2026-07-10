# typed: false
# frozen_string_literal: true

module Cms
  module Archivable
    extend ActiveSupport::Concern

    included do
      scope :active, -> { where(archived_at: nil) }
      scope :archived, -> { where.not(archived_at: nil) }
      validate :validate_cms_archive_fields
    end

    def archived? = archived_at.present?

    private

    def validate_cms_archive_fields
      errors.add(:archive_reason, "must be present when archived") if archived_at.present? && archive_reason.blank?
      errors.add(:archived_at, "must be present with archive reason") if archive_reason.present? && archived_at.blank?
    end
  end
end
