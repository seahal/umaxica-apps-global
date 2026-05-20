# frozen_string_literal: true

class AddEmailPreferenceColumnsToUserEmails < ActiveRecord::Migration[8.2]
  def change
    add_column(:user_emails, :promotional, :boolean, default: true, null: false)
    add_column(:user_emails, :notifiable, :boolean, default: true, null: false)
    add_column(:user_emails, :subscribable, :boolean, default: true, null: false)
  end
end
