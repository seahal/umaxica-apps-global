# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: publishing_publications
# Database name: publishing
#
#  id                            :bigint           not null, primary key
#  cancellation_reason           :string
#  cancelled_at                  :datetime
#  effective_from                :datetime         not null
#  effective_until               :datetime
#  terminated_at                 :datetime
#  termination_reason            :string
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  created_by_operator_public_id :string(21)
#  entry_id                      :bigint           not null
#  entry_version_id              :bigint           not null
#  public_id                     :string(21)       not null
#
# Indexes
#
#  excl_publishing_publication_windows                (entry_id, tstzrange(effective_from, effective_until, '[)'::text)) WHERE (cancelled_at IS NULL) USING gist
#  index_publishing_publications_on_entry_id          (entry_id)
#  index_publishing_publications_on_entry_version_id  (entry_version_id)
#  index_publishing_publications_on_public_id         (public_id) UNIQUE
#
# Foreign Keys
#
#  fk_publishing_publication_version_entry  ([entry_version_id, entry_id] => publishing_entry_versions[id, entry_id]) ON DELETE => restrict
#  fk_rails_...                             (entry_id => publishing_entries.id) ON DELETE => restrict
#
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
