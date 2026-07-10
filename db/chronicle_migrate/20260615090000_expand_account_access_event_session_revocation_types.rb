# frozen_string_literal: true

class ExpandAccountAccessEventSessionRevocationTypes < ActiveRecord::Migration[8.2]
  CONSTRAINT_NAME = "chk_account_access_events_event_type"
  OLD_EVENT_TYPES = %w(admin_lock admin_lock_reaffirmed admin_unlock).freeze
  NEW_EVENT_TYPES = (OLD_EVENT_TYPES + %w(emergency_session_revoke session_purge)).freeze

  def up
    replace_event_type_constraint!(NEW_EVENT_TYPES)
  end

  def down
    replace_event_type_constraint!(OLD_EVENT_TYPES)
  end

  private

  def replace_event_type_constraint!(event_types)
    remove_check_constraint(:account_access_events, name: CONSTRAINT_NAME)
    add_check_constraint(
      :account_access_events,
      "event_type IN (#{event_types.map { |event_type| quote(event_type) }.join(', ')})",
      name: CONSTRAINT_NAME,
      validate: false,
    )
  end
end
