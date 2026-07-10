# frozen_string_literal: true

class AddEmailPreferenceColumnsToStaffEmails < ActiveRecord::Migration[8.2]
  def change
    add_column(:staff_emails, :promotional, :boolean, default: true, null: false)
    add_column(:staff_emails, :notifiable, :boolean, default: true, null: false)
    add_column(:staff_emails, :subscribable, :boolean, default: true, null: false)
  end
end
