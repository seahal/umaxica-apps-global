# frozen_string_literal: true

class SetDefaultEmptyStringOnStaffIdentityStrings < ActiveRecord::Migration[8.2]
  def change
    columns = {
      staff_identity_audits: %i(actor_type event_id ip_address),
      staff_identity_emails: %i(address otp_private_key),
      staff_identity_passkeys: %i(description),
      staff_identity_secrets: %i(name password_digest),
      staff_identity_telephones: %i(number otp_private_key),
      staff_passkeys: %i(external_id name transports user_handle),
      staff_recovery_codes: %i(recovery_code_digest),
      staffs: %i(public_id webauthn_id),
    }

    columns.each do |table, cols|
      cols.each do |col|
        change_column_default(table, col, from: nil, to: "")
      end
    end
  end
end
