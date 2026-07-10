# frozen_string_literal: true

class CreateMemberStatuses < ActiveRecord::Migration[8.2]
  def change
    create_table(:member_statuses) do |t|
      t.timestamps
    end

    add_index(:member_statuses, "lower((id)::text)", unique: true, name: "index_member_identity_statuses_on_lower_id")
  end
end
