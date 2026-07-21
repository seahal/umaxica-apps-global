# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: publishing_entry_slugs
# Database name: publishing
#
#  id               :bigint           not null, primary key
#  canonicalized_at :datetime
#  locale           :string           not null
#  redirected_at    :datetime
#  slug             :string           not null
#  state            :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  edition_id       :bigint           not null
#  entry_id         :bigint           not null
#  public_id        :string(21)       not null
#
# Indexes
#
#  index_publishing_entry_slugs_on_edition_id           (edition_id)
#  index_publishing_entry_slugs_on_edition_id_and_slug  (edition_id,slug) UNIQUE
#  index_publishing_entry_slugs_on_entry_id             (entry_id)
#  index_publishing_entry_slugs_on_public_id            (public_id) UNIQUE
#  uidx_publishing_slug_canonical                       (entry_id) UNIQUE WHERE ((state)::text = 'canonical'::text)
#  uidx_publishing_slug_reserved                        (entry_id) UNIQUE WHERE ((state)::text = 'reserved'::text)
#
# Foreign Keys
#
#  fk_publishing_slug_edition_locale  ([edition_id, locale] => publishing_editions[id, locale]) ON DELETE => restrict
#  fk_publishing_slug_entry_locale    ([entry_id, locale] => publishing_entries[id, locale]) ON DELETE => restrict
#  fk_rails_...                       (edition_id => publishing_editions.id) ON DELETE => restrict
#  fk_rails_...                       (entry_id => publishing_entries.id) ON DELETE => restrict
#
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
