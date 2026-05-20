# frozen_string_literal: true

class RenameClientSubjectsToIdentities < ActiveRecord::Migration[8.2]
  def change
    # No-op: the app_zenith schema and the preceding undeployed create migration
    # now use client_identity names directly.
  end
end
