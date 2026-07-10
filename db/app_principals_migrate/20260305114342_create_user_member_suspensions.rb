# frozen_string_literal: true

class CreateUserMemberSuspensions < ActiveRecord::Migration[8.2]
  def change
    create_table(:user_member_suspensions) do |t|
      t.references(:user, null: false, foreign_key: true, type: :bigint)
      t.references(:member, null: false, foreign_key: true, type: :bigint)

      t.timestamps

      t.index(%i(user_id member_id), unique: true)
    end
  end
end
