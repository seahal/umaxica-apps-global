# frozen_string_literal: true

class RenameVisitorSubjectsToIdentities < ActiveRecord::Migration[8.2]
  def change
    # No-op: the com_zenith schema and the preceding undeployed create migration
    # now use visitor_identity names directly.
  end
end
