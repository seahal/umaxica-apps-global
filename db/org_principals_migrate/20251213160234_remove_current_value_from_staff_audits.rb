# frozen_string_literal: true

class RemoveCurrentValueFromStaffAudits < ActiveRecord::Migration[8.2]
  def change
    remove_column(:staff_identity_audits, :current_value, :text)
  end
end
