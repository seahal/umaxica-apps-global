# frozen_string_literal: true

class ValidateAccountAccessEventSessionRevocationTypes < ActiveRecord::Migration[8.2]
  CONSTRAINT_NAME = "chk_account_access_events_event_type"

  def change
    validate_check_constraint(:account_access_events, name: CONSTRAINT_NAME)
  end
end
