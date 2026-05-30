# frozen_string_literal: true

class DropUnusedScavengerChronicles < ActiveRecord::Migration[8.1]
  def up
    safety_assured { drop_table :scavenger_regional_chronicles }
    safety_assured { drop_table :scavenger_regional_chronicle_events }
    safety_assured { drop_table :scavenger_regional_chronicle_statuses }
    safety_assured { drop_table :scavenger_global_chronicles }
    safety_assured { drop_table :scavenger_global_chronicle_events }
    safety_assured { drop_table :scavenger_global_chronicle_statuses }
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "scavenger chronicle data was intentionally removed"
  end
end
