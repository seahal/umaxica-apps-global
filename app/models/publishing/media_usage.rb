# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: publishing_media_usages
# Database name: publishing
#
#  id                    :bigint           not null, primary key
#  alt_text              :string
#  block_path            :string
#  caption               :text
#  field_path            :string
#  locale                :string           not null
#  position              :integer          default(0), not null
#  presentation_metadata :jsonb
#  role                  :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  entry_id              :bigint           not null
#  entry_revision_id     :bigint
#  entry_version_id      :bigint
#  media_file_id         :bigint           not null
#  public_id             :string(21)       not null
#
# Indexes
#
#  index_publishing_media_usages_on_entry_id       (entry_id)
#  index_publishing_media_usages_on_media_file_id  (media_file_id)
#  index_publishing_media_usages_on_public_id      (public_id) UNIQUE
#  uidx_publishing_revision_media_position         (entry_revision_id,role,field_path,block_path,position) UNIQUE WHERE (entry_revision_id IS NOT NULL)
#  uidx_publishing_version_media_position          (entry_version_id,role,field_path,block_path,position) UNIQUE WHERE (entry_version_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_publishing_media_revision_entry  ([entry_revision_id, entry_id] => publishing_entry_revisions[id, entry_id]) ON DELETE => restrict
#  fk_publishing_media_version_entry   ([entry_version_id, entry_id] => publishing_entry_versions[id, entry_id]) ON DELETE => restrict
#  fk_rails_...                        (entry_id => publishing_entries.id) ON DELETE => restrict
#  fk_rails_...                        (media_file_id => publishing_media_files.id) ON DELETE => restrict
#
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
