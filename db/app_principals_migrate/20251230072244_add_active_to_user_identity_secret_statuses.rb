# frozen_string_literal: true

class AddActiveToUserIdentitySecretStatuses < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      # No-op: intentionally left blank.
    end
  end

  def down
  end
end
