class DropLegacyRetentionColumnsFromOperators < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      remove_index :operators, :shreddable_at, if_exists: true
      remove_column :operators, :shreddable_at, :datetime, if_exists: true
      remove_column :org_preferences, :compromised_at, :datetime, if_exists: true
    end
  end
end
