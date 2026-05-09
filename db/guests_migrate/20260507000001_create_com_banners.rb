# frozen_string_literal: true

class CreateComBanners < ActiveRecord::Migration[8.2]
  def change
    create_table(:com_banners) do |t|
      t.string(:title, null: false, default: "")
      t.text(:body, null: false)
      t.boolean(:published, null: false, default: false)
      t.datetime(:starts_at, null: false, default: -> { "CURRENT_TIMESTAMP" })
      t.datetime(:ends_at, null: false, default: -> { "'9999-12-31 23:59:59 UTC'" })

      t.timestamps
      t.check_constraint("ends_at > starts_at", name: "com_banners_ends_at_after_starts_at")
    end
  end
end
