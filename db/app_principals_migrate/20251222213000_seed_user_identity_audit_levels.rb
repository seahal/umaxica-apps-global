# frozen_string_literal: true

class SeedUserIdentityAuditLevels < ActiveRecord::Migration[8.2]
  LEVELS = %w(NONE DEBUG INFO WARN ERROR FATAL UNKNOWN).freeze

  def up
    LEVELS.each do |level|
      # No-op: intentionally left blank.
    end
  end

  def down
  end
end
