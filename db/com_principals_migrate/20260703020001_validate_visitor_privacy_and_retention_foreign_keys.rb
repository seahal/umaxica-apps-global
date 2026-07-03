# frozen_string_literal: true

class ValidateVisitorPrivacyAndRetentionForeignKeys < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key :visitor_privacy_requests, :visitor_privacy_request_statuses
    validate_foreign_key :visitor_retention_holds, :visitor_retention_hold_statuses
  end
end
