# frozen_string_literal: true

class RenameClientTotpCredentialStatusColumn < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      rename_column :client_totp_credentials,
                    :user_identity_one_time_password_status_id,
                    :user_identity_totp_credential_status_id
    end
  end
end
