# typed: false
# frozen_string_literal: true

module Publishing
  class Publication < PublishingRecord
    self.table_name = "publishing_publications"

    include PublicId

    belongs_to :entry, class_name: "Publishing::Entry", inverse_of: :publications
    belongs_to :entry_version, class_name: "Publishing::EntryVersion", inverse_of: :publications

    scope :active, -> {
      now = Time.current
      where(cancelled_at: nil)
        .where(effective_from: ..now)
        .where("effective_until IS NULL OR effective_until > ?", now)
    }

    def cancelled? = cancelled_at.present?

    def terminated? = terminated_at.present?
  end
end
