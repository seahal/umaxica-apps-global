class DropLegacyCompromisedAtFromPrincipals < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      remove_column :app_preferences, :compromised_at, :datetime, if_exists: true
    end
  end
end
