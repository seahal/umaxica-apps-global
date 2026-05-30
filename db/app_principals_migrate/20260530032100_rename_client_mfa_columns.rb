# frozen_string_literal: true

class RenameClientMfaColumns < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      rename_column :clients, :multi_factor_id, :mfa_level_id
      rename_column :clients, :multi_factor_status_id, :mfa_status_id
    end
  end
end
