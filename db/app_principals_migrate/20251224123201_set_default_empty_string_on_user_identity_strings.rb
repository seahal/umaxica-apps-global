# frozen_string_literal: true

class SetDefaultEmptyStringOnUserIdentityStrings < ActiveRecord::Migration[8.2]
  def change
    columns = {
      apple_auths: %i(email name provider uid),
      google_auths: %i(email image_url name provider uid),
      roles: %i(key name),
      user_identity_audits: %i(actor_type event_id ip_address),
      user_identity_emails: %i(address otp_private_key),
      user_identity_one_time_passwords: %i(private_key user_identity_one_time_password_status_id),
      user_identity_passkeys: %i(description webauthn_id),
      user_identity_secrets: %i(name password_digest),
      user_identity_social_apples: %i(email image refresh_token token uid),
      user_identity_social_googles: %i(email image refresh_token token uid),
      user_identity_telephones: %i(number otp_private_key),
      user_passkeys: %i(external_id name transports user_handle),
      users: %i(public_id webauthn_id),
    }

    columns.each do |table, cols|
      cols.each do |col|
        change_column_default(table, col, from: nil, to: "")
      end
    end
  end
end
