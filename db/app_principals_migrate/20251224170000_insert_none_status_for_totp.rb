# frozen_string_literal: true

class InsertNoneStatusForTotp < ActiveRecord::Migration[8.2]
  def change
    # Insert NONE status if missing, to satisfy FK for default
    up_only do
      # No-op: intentionally left blank.
    end
  end
end
