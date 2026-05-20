# frozen_string_literal: true

class SetDefaultInfinityForUserWithdrawnAt < ActiveRecord::Migration[8.2]
  def up
    change_column_default(:users, :withdrawn_at, from: nil, to: -> { "'+infinity'::timestamp" })

    # Update existing NULL values to +infinity
    execute("UPDATE users SET withdrawn_at = '+infinity'::timestamp WHERE withdrawn_at IS NULL")
  end

  def down
    change_column_default(:users, :withdrawn_at, from: -> { "'+infinity'::timestamp" }, to: nil)
  end
end
