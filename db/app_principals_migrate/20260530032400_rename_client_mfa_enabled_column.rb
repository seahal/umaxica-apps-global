# frozen_string_literal: true

class RenameClientMfaEnabledColumn < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      rename_column :clients, :multi_factor_enabled, :mfa_level_enabled
    end
  end
end
