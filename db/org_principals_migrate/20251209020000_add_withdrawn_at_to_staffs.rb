# frozen_string_literal: true

class AddWithdrawnAtToStaffs < ActiveRecord::Migration[8.2]
  def change
    add_column(:staffs, :withdrawn_at, :datetime) unless column_exists?(:staffs, :withdrawn_at)
  end
end
