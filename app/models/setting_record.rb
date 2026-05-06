# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
class SettingRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :setting, reading: :setting_replica }

  before_validation :set_next_position, if: -> { self.class.column_names.include?("position") }

  private

  def set_next_position
    # Always calculate next position to ensure uniqueness
    # This prevents conflicts with fixtures and parallel test runs
    self.position = (self.class.maximum(:position) || 0) + 1
  end
end
