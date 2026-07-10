# frozen_string_literal: true

class AddLockingFieldsToUserIdentities < ActiveRecord::Migration[8.2]
  def change
    tables = %i(
      user_identity_emails
      user_identity_telephones
    )

    tables.each do |table|
      change_table(table, bulk: true) do |t|
        t.integer(:otp_attempts_count, default: 0, null: false)
        t.datetime(:locked_at)
      end
    end
  end
end
