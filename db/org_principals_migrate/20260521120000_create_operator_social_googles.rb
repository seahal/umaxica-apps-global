# frozen_string_literal: true

class CreateOperatorSocialGoogles < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    create_table :operator_social_google_statuses do |t|
    end

    create_table :operator_social_googles do |t|
      t.bigint :staff_id, null: false
      t.string :provider, null: false, default: "google_org"
      t.string :uid, null: false, default: ""
      t.string :token, null: false, default: ""
      t.string :refresh_token, null: false, default: ""
      t.integer :token_expires_at, null: false
      t.bigint :status_id, null: false, default: 1
      t.datetime :last_authenticated_at
      t.timestamps

      t.index :staff_id, unique: true, where: "staff_id IS NOT NULL",
                         name: "index_operator_social_googles_on_staff_id_unique"
      t.index [:uid, :provider], unique: true,
                                name: "index_operator_social_googles_on_uid_and_provider"
      t.index :status_id, name: "index_operator_social_googles_on_status_id"
      t.index :token_expires_at, name: "index_operator_social_googles_on_token_expires_at"
    end

    add_foreign_key :operator_social_googles, :operators, column: :staff_id, validate: false
    add_foreign_key :operator_social_googles, :operator_social_google_statuses, column: :status_id, validate: false
    validate_foreign_key :operator_social_googles, :operators
    validate_foreign_key :operator_social_googles, :operator_social_google_statuses
  end
end
