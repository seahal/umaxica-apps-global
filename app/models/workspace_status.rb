# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: workspace_statuses
# Database name: operator
#
#  id :bigint           not null, primary key
#
class WorkspaceStatus < OperatorRecord
  include ReferenceRecord

  self.primary_key = "id"

  # Fixed IDs - do not modify these values
  NOTHING = 0
  LEGACY_NOTHING = 1
  DEFAULTS = [NOTHING, LEGACY_NOTHING].freeze

  has_many :workspaces, dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
