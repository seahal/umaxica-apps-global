# typed: false
# frozen_string_literal: true

module Publishing
  class Edition < PublishingRecord
    self.table_name = "publishing_editions"

    include PublicId

    AUDIENCES = %w(app com org).freeze
    SURFACES = %w(info docs news help).freeze

    has_many :entries, class_name: "Publishing::Entry", inverse_of: :edition, dependent: :restrict_with_exception
    has_many :entry_slugs, class_name: "Publishing::EntrySlug", inverse_of: :edition, dependent: :restrict_with_exception

    validates :audience, inclusion: { in: AUDIENCES }
    validates :surface, inclusion: { in: SURFACES }
    validates :locale, presence: true
  end
end
