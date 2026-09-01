# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: publishing_editions
# Database name: publishing
#
#  id          :bigint           not null, primary key
#  audience    :string           not null
#  locale      :string           not null
#  region_code :string
#  surface     :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  public_id   :string(21)       not null
#
# Indexes
#
#  index_publishing_editions_on_id_and_locale  (id,locale) UNIQUE
#  index_publishing_editions_on_public_id      (public_id) UNIQUE
#  uidx_publishing_editions_scope              (audience,surface,locale) UNIQUE
#
module Publishing
  class Edition < PublishingRecord
    self.table_name = "publishing_editions"

    include PublicId

    AUDIENCES = %w(app com org).freeze
    SURFACES = %w(info docs news help).freeze

    has_many :entries, class_name: "Publishing::Entry", inverse_of: :edition, dependent: :restrict_with_exception
    has_many :entry_slugs, class_name: "Publishing::EntrySlug", inverse_of: :edition,
                           dependent: :restrict_with_exception

    validates :audience, inclusion: { in: AUDIENCES }
    validates :surface, inclusion: { in: SURFACES }
    validates :locale, presence: true
  end
end
