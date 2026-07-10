# frozen_string_literal: true

class AddMultiFactorEnabledToStaffs < ActiveRecord::Migration[8.2]
  def change
    add_column(:staffs, :multi_factor_enabled, :boolean, null: false, default: false)
  end
end
