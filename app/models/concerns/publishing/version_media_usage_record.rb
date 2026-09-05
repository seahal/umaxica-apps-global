# frozen_string_literal: true

module Publishing
  module VersionMediaUsageRecord
    extend ActiveSupport::Concern

    included do
      include PublicId

      before_update { raise(ActiveRecord::ReadOnlyRecord, "#{self.class.name} is immutable") }
      before_destroy { raise(ActiveRecord::ReadOnlyRecord, "#{self.class.name} is immutable") }

      family = name.deconstantize
      belongs_to :media_file, class_name: "Publishing::MediaFile"
      belongs_to :entry_version, class_name: "#{family}::EntryVersion", inverse_of: :media_usages

      validates :role, presence: true
      validates :position, numericality: { greater_than_or_equal_to: 0, only_integer: true }
    end
  end
end
