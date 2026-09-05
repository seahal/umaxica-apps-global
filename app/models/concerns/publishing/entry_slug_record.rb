# frozen_string_literal: true

module Publishing
  module EntrySlugRecord
    extend ActiveSupport::Concern

    STATES = %w(reserved canonical redirect).freeze

    included do
      include PublicId

      family = name.deconstantize
      belongs_to :entry, class_name: "#{family}::Entry", inverse_of: :slugs
      validates :state, inclusion: { in: STATES }
      scope :canonical, -> { where(state: "canonical") }
    end
  end
end
