# frozen_string_literal: true

class CreateVisitorBanners < ActiveRecord::Migration[8.2]
  def change
    create_table(:visitor_banners) do |t|
      t.bigint(:visitor_id, null: false)
      t.string(:title, default: "", null: false)
      t.text(:body, null: false)
      t.boolean(:published, default: false, null: false)
      t.datetime(:starts_at, default: -> { "CURRENT_TIMESTAMP" }, null: false)
      t.datetime(:ends_at, default: "9999-12-31 23:59:59", null: false)
      t.timestamps

      t.index(:visitor_id)
      t.check_constraint("ends_at > starts_at", name: "visitor_banners_ends_at_after_starts_at")
    end

    add_foreign_key(:visitor_banners, :visitors, validate: false)
  end
end
