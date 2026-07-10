# frozen_string_literal: true

class ReseedUserEmailStatusReferenceRows < ActiveRecord::Migration[8.2]
  USER_EMAIL_STATUS_IDS = [
    1, # UNVERIFIED
    2, # VERIFIED
    3, # SUSPENDED
    4, # DELETED
    5, # NEYO / NOTHING
    6, # UNVERIFIED_WITH_SIGN_UP
    7, # VERIFIED_WITH_SIGN_UP
  ].freeze

  def up
    return unless table_exists?(:user_email_statuses)

    safety_assured do
      USER_EMAIL_STATUS_IDS.each do |id|
        execute(<<~SQL.squish)
          INSERT INTO user_email_statuses (id)
          VALUES (#{connection.quote(id)})
          ON CONFLICT (id) DO NOTHING
        SQL
      end

      sequence_name = select_value("SELECT pg_get_serial_sequence('user_email_statuses', 'id')")
      if sequence_name.present?
        execute("SELECT setval(#{connection.quote(sequence_name)}, #{USER_EMAIL_STATUS_IDS.max}, true)")
      end
    end
  end

  def down
    # No-op: these fixed reference rows may be referenced by user_emails.
  end
end
