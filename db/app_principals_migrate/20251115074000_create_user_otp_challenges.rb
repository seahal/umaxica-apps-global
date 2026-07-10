# frozen_string_literal: true

class CreateUserOtpChallenges < ActiveRecord::Migration[8.0]
  def change
    create_table(:user_otp_challenges) do |t|
      t.bigint(:user_id, null: false)
      t.string(:address, null: false)
      t.string(:otp_private_key, null: false)
      t.bigint(:otp_counter, null: false)
      t.datetime(:expires_at, null: false)

      t.timestamps
    end

    add_index(:user_otp_challenges, :user_id)
    add_index(:user_otp_challenges, :address)
    add_index(:user_otp_challenges, :expires_at)
  end
end
