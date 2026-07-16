# typed: false
# frozen_string_literal: true

module Publishing
  class EntrySlug < PublishingRecord
    self.table_name = "publishing_entry_slugs"

    include PublicId

    STATES = %w(reserved canonical redirect).freeze

    belongs_to :entry, class_name: "Publishing::Entry", inverse_of: :slugs
    belongs_to :edition, class_name: "Publishing::Edition", inverse_of: :entry_slugs

    validates :state, inclusion: { in: STATES }

    scope :canonical, -> { where(state: "canonical") }
  end
end
