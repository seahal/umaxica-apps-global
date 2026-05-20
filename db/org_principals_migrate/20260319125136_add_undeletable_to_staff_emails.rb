# typed: false
# frozen_string_literal: true

class AddUndeletableToStaffEmails < ActiveRecord::Migration[8.0]
  def change
    add_column(:staff_emails, :undeletable, :boolean, default: false, null: false)
  end
end
