# typed: false
# frozen_string_literal: true

module Publishing
  class Entry < PublishingRecord
    self.table_name = "publishing_entries"

    include PublicId

    belongs_to :edition, class_name: "Publishing::Edition", inverse_of: :entries
    belongs_to :current_revision, class_name: "Publishing::EntryRevision", optional: true

    has_many :revisions, class_name: "Publishing::EntryRevision", inverse_of: :entry, dependent: :restrict_with_exception
    has_many :versions, class_name: "Publishing::EntryVersion", inverse_of: :entry, dependent: :restrict_with_exception
    has_many :slugs, class_name: "Publishing::EntrySlug", inverse_of: :entry, dependent: :restrict_with_exception
    has_many :publications, class_name: "Publishing::Publication", inverse_of: :entry, dependent: :restrict_with_exception
    has_many :media_usages, class_name: "Publishing::MediaUsage", inverse_of: :entry, dependent: :restrict_with_exception

    def archived? = archived_at.present?
  end
end
