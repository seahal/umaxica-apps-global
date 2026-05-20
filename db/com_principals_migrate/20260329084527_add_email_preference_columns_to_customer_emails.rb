# frozen_string_literal: true

class AddEmailPreferenceColumnsToCustomerEmails < ActiveRecord::Migration[8.2]
  def change
    add_column(:customer_emails, :promotional, :boolean, default: true, null: false)
    add_column(:customer_emails, :notifiable, :boolean, default: true, null: false)
    add_column(:customer_emails, :subscribable, :boolean, default: true, null: false)
  end
end
