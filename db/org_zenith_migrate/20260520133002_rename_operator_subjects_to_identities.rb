# frozen_string_literal: true

class RenameOperatorSubjectsToIdentities < ActiveRecord::Migration[8.2]
  def change
    # No-op: the org_zenith schema and the preceding undeployed create migration
    # now use operator_identity names directly.
  end
end
