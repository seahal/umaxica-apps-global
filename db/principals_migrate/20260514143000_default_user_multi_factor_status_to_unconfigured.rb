# frozen_string_literal: true

class DefaultUserMultiFactorStatusToUnconfigured < ActiveRecord::Migration[8.2]
  def up
    change_column_default :users, :multi_factor_status_id, from: 0, to: 5
  end

  def down
    change_column_default :users, :multi_factor_status_id, from: 5, to: 0
  end
end
