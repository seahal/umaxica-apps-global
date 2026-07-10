# frozen_string_literal: true

class DropUserOtpChallenges < ActiveRecord::Migration[8.0]
  def change
    drop_table(:user_otp_challenges) do |t|
      t.bigint(:user_id, null: false)
      t.string(:address, null: false)
      t.string(:otp_private_key, null: false)
      t.text(:otp_counter, null: false)
      t.datetime(:expires_at, null: false)

      t.timestamps

      t.index(:user_id)
      t.index(:address)
      t.index(:expires_at)
    end
  end
end
