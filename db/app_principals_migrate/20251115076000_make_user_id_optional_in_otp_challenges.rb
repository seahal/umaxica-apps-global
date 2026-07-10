# frozen_string_literal: true

class MakeUserIdOptionalInOtpChallenges < ActiveRecord::Migration[8.0]
  def change
    change_column_null(:user_otp_challenges, :user_id, true)
  end
end
