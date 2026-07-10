# frozen_string_literal: true

class AddTestSeederGuestData < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!
  STATUS_IDS = %w(UNVERIFIED VERIFIED ACTIVE OTHERS SECURITY_ISSUE).freeze

  def up
    # No-op: data seeding moved to fixtures.
  end

  def down
    # No-op: data seeding moved to fixtures.
  end
end
