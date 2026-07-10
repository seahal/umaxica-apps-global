# frozen_string_literal: true

class AddDefaultsToUserIdentityAudits < ActiveRecord::Migration[8.2]
  def change
    reversible do |dir|
      dir.up do
        change_table(:user_identity_audits, bulk: true) do |t|
          t.change_default(:actor_id, from: nil, to: "00000000-0000-0000-0000-000000000000")
          t.change_default(:timestamp, from: nil, to: -Float::INFINITY)
        end
      end
      dir.down do
        change_table(:user_identity_audits, bulk: true) do |t|
          t.change_default(:actor_id, from: "00000000-0000-0000-0000-000000000000", to: nil)
          t.change_default(:timestamp, from: -Float::INFINITY, to: nil)
        end
      end
    end
  end
end
