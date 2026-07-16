# typed: false
# frozen_string_literal: true

module Publishing
  class EntryVersion < PublishingRecord
    self.table_name = "publishing_entry_versions"

    include PublicId

    belongs_to :entry, class_name: "Publishing::Entry", inverse_of: :versions
    belongs_to :entry_revision, class_name: "Publishing::EntryRevision"

    has_many :publications, class_name: "Publishing::Publication", inverse_of: :entry_version, dependent: :restrict_with_exception
    has_many :media_usages, class_name: "Publishing::MediaUsage", inverse_of: :entry_version, dependent: :restrict_with_exception

    # Version rows are immutable release snapshots; only the initial insert is allowed.
    before_update { raise ActiveRecord::ReadOnlyRecord, "Publishing::EntryVersion is immutable" }
    before_destroy { raise ActiveRecord::ReadOnlyRecord, "Publishing::EntryVersion is immutable" }
  end
end
