# frozen_string_literal: true

class ChangeOtpCounterToText < ActiveRecord::Migration[8.0]
  def up
    change_column(:user_otp_challenges, :otp_counter, :text)
  end

  def down
    change_column(:user_otp_challenges, :otp_counter, :bigint)
  end
end
