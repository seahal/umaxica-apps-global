# frozen_string_literal: true

class DropLegacyGoogleAuths < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      drop_table(:google_auths, if_exists: true)
    end
  end

  def down
    create_table(:google_auths) do |t|
      t.references(:user, null: false, foreign_key: true, type: :bigint)
      t.string(:provider, null: false, default: "")
      t.string(:uid, null: false, default: "")
      t.string(:email, null: false, default: "")
      t.string(:name, null: false, default: "")
      t.string(:image_url, null: false, default: "")
      t.text(:access_token, null: false)
      t.text(:refresh_token, null: false)
      t.datetime(:expires_at, null: false)
      t.text(:raw_info, null: false)

      t.timestamps
    end
  end
end
