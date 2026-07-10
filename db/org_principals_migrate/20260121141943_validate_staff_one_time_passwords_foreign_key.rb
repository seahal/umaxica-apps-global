# frozen_string_literal: true

class ValidateStaffOneTimePasswordsForeignKey < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key(:staff_one_time_passwords, :staff_one_time_password_statuses)
  end
end
