# frozen_string_literal: true

class InsertDummyIdentities < ActiveRecord::Migration[8.2]
  def change
    # Insert Statuses first
    up_only do
      # Dummy User and Staff
      # public_id required NOT NULL default ""

      # Dummy Workspace
    end
  end
end
