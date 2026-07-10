# frozen_string_literal: true

class FixUserIdentityStatusIdDefault < ActiveRecord::Migration[8.2]
  def up

    change_column_default(:users, :user_identity_status_id, from: "NONE", to: nil)
    change_column_null(:users, :user_identity_status_id, true)

  end

  def down

    change_column_null(:users, :user_identity_status_id, false)
    change_column_default(:users, :user_identity_status_id, from: nil, to: "NONE")

  end
end
