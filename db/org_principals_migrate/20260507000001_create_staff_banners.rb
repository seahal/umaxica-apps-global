# frozen_string_literal: true

class CreateStaffBanners < ActiveRecord::Migration[8.2]
  def change
    create_table(:staff_banners) do |t|
      t.bigint(:staff_id, null: false)
      t.string(:title, null: false, default: "")
      t.text(:body, null: false)
      t.boolean(:published, null: false, default: false)
      t.datetime(:starts_at, null: false, default: -> { "CURRENT_TIMESTAMP" })
      t.datetime(:ends_at, null: false, default: -> { "'9999-12-31 23:59:59 UTC'" })

      t.timestamps
      t.check_constraint("ends_at > starts_at", name: "staff_banners_ends_at_after_starts_at")
    end

    add_index(:staff_banners, :staff_id)
    add_foreign_key(:staff_banners, :staffs, validate: false)
  end
end
