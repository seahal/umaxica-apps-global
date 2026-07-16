# typed: false
# frozen_string_literal: true

module Publishing
  class EntryRevision < PublishingRecord
    self.table_name = "publishing_entry_revisions"

    include PublicId

    belongs_to :entry, class_name: "Publishing::Entry", inverse_of: :revisions
    belongs_to :restored_from_revision, class_name: "Publishing::EntryRevision", optional: true
    belongs_to :restored_from_version, class_name: "Publishing::EntryVersion", optional: true

    has_many :media_usages, class_name: "Publishing::MediaUsage", inverse_of: :entry_revision, dependent: :restrict_with_exception
  end
end
