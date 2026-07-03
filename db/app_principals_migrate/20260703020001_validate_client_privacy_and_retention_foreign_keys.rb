# frozen_string_literal: true

class ValidateClientPrivacyAndRetentionForeignKeys < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key :client_privacy_requests, :client_privacy_request_statuses
    validate_foreign_key :client_retention_holds, :client_retention_hold_statuses
  end
end
