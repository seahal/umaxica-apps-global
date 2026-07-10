# frozen_string_literal: true

class FixUserAuditEventDefaults < ActiveRecord::Migration[8.2]
  def change
    change_column_default(:user_identity_audits, :event_id, from: "", to: "NONE")

    up_only do
      execute("UPDATE user_identity_audits SET event_id = 'NONE' WHERE event_id = ''")
    end
  end
end
