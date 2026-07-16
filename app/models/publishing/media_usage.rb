# typed: false
# frozen_string_literal: true

module Publishing
  class MediaUsage < PublishingRecord
    self.table_name = "publishing_media_usages"

    include PublicId

    belongs_to :media_file, class_name: "Publishing::MediaFile", inverse_of: :media_usages
    belongs_to :entry, class_name: "Publishing::Entry", inverse_of: :media_usages
    belongs_to :entry_revision, class_name: "Publishing::EntryRevision", optional: true, inverse_of: :media_usages
    belongs_to :entry_version, class_name: "Publishing::EntryVersion", optional: true, inverse_of: :media_usages

    validate :exactly_one_owner

    private

    def exactly_one_owner
      return if [entry_revision_id, entry_version_id].compact.size == 1

      errors.add(:base, "must belong to exactly one of entry_revision or entry_version")
    end
  end
end
