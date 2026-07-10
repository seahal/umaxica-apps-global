# typed: false
# frozen_string_literal: true

class AddUndeletableToUserEmails < ActiveRecord::Migration[8.0]
  def change
    add_column(:user_emails, :undeletable, :boolean, default: false, null: false)
  end
end
