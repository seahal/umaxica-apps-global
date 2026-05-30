# frozen_string_literal: true

class RenameVisitorSecretCredentialColumns < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      rename_column :visitor_secret_credentials, :visitor_secret_kind_id, :visitor_secret_credential_kind_id
      rename_column :visitor_secret_credentials, :visitor_secret_status_id, :visitor_secret_credential_status_id
    end
  end
end
