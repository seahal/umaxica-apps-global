# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: publishing_entry_revisions
# Database name: publishing
#
#  id                            :bigint           not null, primary key
#  body                          :jsonb            not null
#  content_digest                :string(64)       not null
#  locale                        :string           not null
#  schema_version                :integer          not null
#  sequence                      :integer          not null
#  summary                       :text
#  title                         :string           not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  created_by_operator_public_id :string(21)
#  entry_id                      :bigint           not null
#  public_id                     :string(21)       not null
#  restored_from_revision_id     :bigint
#  restored_from_version_id      :bigint
#
# Indexes
#
#  index_publishing_entry_revisions_on_entry_id                    (entry_id)
#  index_publishing_entry_revisions_on_entry_id_and_sequence       (entry_id,sequence) UNIQUE
#  index_publishing_entry_revisions_on_id_and_entry_id             (id,entry_id) UNIQUE
#  index_publishing_entry_revisions_on_id_and_entry_id_and_locale  (id,entry_id,locale) UNIQUE
#  index_publishing_entry_revisions_on_id_and_locale               (id,locale) UNIQUE
#  index_publishing_entry_revisions_on_public_id                   (public_id) UNIQUE
#
# Foreign Keys
#
#  fk_publishing_restore_revision_entry  ([restored_from_revision_id, entry_id] => publishing_entry_revisions[id, entry_id]) ON DELETE => restrict
#  fk_publishing_restore_version_entry   ([restored_from_version_id, entry_id] => publishing_entry_versions[id, entry_id]) ON DELETE => restrict
#  fk_publishing_revision_entry_locale   ([entry_id, locale] => publishing_entries[id, locale]) ON DELETE => restrict
#  fk_rails_...                          (entry_id => publishing_entries.id) ON DELETE => restrict
#
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
