# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: workspace_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
class WorkspaceStatus < OrgPrincipalRecord
  include ReferenceRecord

  self.primary_key = "id"

  # Fixed IDs - do not modify these values
  NOTHING = 0
  LEGACY_NOTHING = 1
  DEFAULTS = [NOTHING, LEGACY_NOTHING].freeze

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
