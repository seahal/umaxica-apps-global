# frozen_string_literal: true

class EnforceNotNullOnStaffIdentityAuthColumns < ActiveRecord::Migration[8.2]
  INFINITY_PAST = '-infinity'
  NIL_UUID = '00000000-0000-0000-0000-000000000000'

  def change
    reversible do |dir|
      dir.up do
        execute("UPDATE staff_passkeys SET sign_count = 0 WHERE sign_count IS NULL")
      end
    end

    change_table(:staff_passkeys, bulk: true) do |t|
      t.change_null(:sign_count, false, 0)
      t.change_default(:sign_count, from: nil, to: 0)
    end

    # staff_identity_emails: locked_at, otp_counter, otp_expires_at, otp_last_sent_at
    reversible do |dir|
      dir.up do
        execute("UPDATE staff_identity_emails SET locked_at = '#{INFINITY_PAST}' WHERE locked_at IS NULL")
        execute("UPDATE staff_identity_emails SET otp_counter = '' WHERE otp_counter IS NULL")
        execute("UPDATE staff_identity_emails SET otp_expires_at = '#{INFINITY_PAST}' WHERE otp_expires_at IS NULL")
        execute("UPDATE staff_identity_emails SET otp_last_sent_at = '#{INFINITY_PAST}' WHERE otp_last_sent_at IS NULL")
      end
    end

    change_table(:staff_identity_emails, bulk: true) do |t|
      t.change_null(:locked_at, false, INFINITY_PAST)
      t.change_default(:locked_at, from: nil, to: -> { "'-infinity'::timestamp" })

      t.change_null(:otp_counter, false, '')
      t.change_default(:otp_counter, from: nil, to: '')

      t.change_null(:otp_expires_at, false, INFINITY_PAST)
      t.change_default(:otp_expires_at, from: nil, to: -> { "'-infinity'::timestamp" })

      t.change_null(:otp_last_sent_at, false, INFINITY_PAST)
      t.change_default(:otp_last_sent_at, from: nil, to: -> { "'-infinity'::timestamp" })
    end

    # staff_identity_telephones: locked_at, otp_counter, otp_expires_at
    reversible do |dir|
      dir.up do
        execute("UPDATE staff_identity_telephones SET locked_at = '#{INFINITY_PAST}' WHERE locked_at IS NULL")
        execute("UPDATE staff_identity_telephones SET otp_counter = '' WHERE otp_counter IS NULL")
        execute("UPDATE staff_identity_telephones SET otp_expires_at = '#{INFINITY_PAST}' WHERE otp_expires_at IS NULL")
      end
    end

    change_table(:staff_identity_telephones, bulk: true) do |t|
      t.change_null(:locked_at, false, INFINITY_PAST)
      t.change_default(:locked_at, from: nil, to: -> { "'-infinity'::timestamp" })

      t.change_null(:otp_counter, false, '')
      t.change_default(:otp_counter, from: nil, to: '')

      t.change_null(:otp_expires_at, false, INFINITY_PAST)
      t.change_default(:otp_expires_at, from: nil, to: -> { "'-infinity'::timestamp" })
    end

    reversible do |dir|
      dir.up do
        execute("UPDATE staff_identity_secrets SET last_used_at = '#{INFINITY_PAST}' WHERE last_used_at IS NULL")
      end
    end

    change_table(:staff_identity_secrets, bulk: true) do |t|
      t.change_null(:last_used_at, false, INFINITY_PAST)
      t.change_default(:last_used_at, from: nil, to: -> { "'-infinity'::timestamp" })
    end
  end
end
