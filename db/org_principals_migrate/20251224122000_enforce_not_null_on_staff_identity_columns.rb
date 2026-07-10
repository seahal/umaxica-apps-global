# frozen_string_literal: true

class EnforceNotNullOnStaffIdentityColumns < ActiveRecord::Migration[8.2]
  def change
    tables = {
      role_assignments: %i(staff_id user_id),
      staff_identity_audits: %i(actor_id actor_type ip_address timestamp),
      staff_identity_emails: %i(address otp_counter otp_private_key staff_id),
      staff_identity_secrets: %i(name password_digest),
      staff_identity_telephones: %i(number otp_counter otp_private_key staff_id),
      staff_passkeys: %i(external_id name public_key sign_count transports user_handle),
      staff_recovery_codes: %i(expires_in recovery_code_digest staff_id),
      staffs: %i(staff_identity_status_id webauthn_id),
    }

    tables.each do |table, columns|
      columns.each do |column|
        change_column_null(table, column, false)
      end
    end
  end
end
