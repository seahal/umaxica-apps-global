class ConsolidateRetentionOnAvatars < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      add_column :avatars, :lapses_at, :datetime, null: false, default: -> { "'infinity'" } unless column_exists?(:avatars, :lapses_at)
      rename_column :avatars, :shreddable_at, :purge_at if column_exists?(:avatars, :shreddable_at)
    end
  end
end
