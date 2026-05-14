# frozen_string_literal: true

class EnsureUserBanners < ActiveRecord::Migration[8.2]
  def change
    unless table_exists?(:user_banners)
      create_table(:user_banners) do |t|
        t.bigint(:user_id, null: false)
        t.string(:title, null: false, default: "")
        t.text(:body, null: false)
        t.boolean(:published, null: false, default: false)
        t.datetime(:starts_at, null: false, default: -> { "CURRENT_TIMESTAMP" })
        t.datetime(:ends_at, null: false, default: -> { "'9999-12-31 23:59:59 UTC'" })

        t.timestamps
        t.check_constraint("ends_at > starts_at", name: "user_banners_ends_at_after_starts_at")
      end
    end

    add_index(:user_banners, :user_id) unless index_exists?(:user_banners, :user_id)
    add_foreign_key(:user_banners, :users, validate: false) unless foreign_key_exists?(:user_banners, :users)
  end
end
