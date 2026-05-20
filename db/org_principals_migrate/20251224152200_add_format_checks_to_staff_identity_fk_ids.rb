# frozen_string_literal: true

require "digest"

class AddFormatChecksToStaffIdentityFkIds < ActiveRecord::Migration[8.2]
  FORMAT_REGEX = "^[A-Z0-9_]+$"

  def change
    add_format_check(:staff_identity_audits, :event_id)
    add_format_check(:staff_identity_audits, :level_id)

    add_format_check(:staff_identity_emails, :staff_identity_email_status_id)
    add_format_check(:staff_identity_secrets, :staff_identity_secret_status_id)
    add_format_check(:staff_identity_telephones, :staff_identity_telephone_status_id)
    add_format_check(:staffs, :staff_identity_status_id)
  end

  private

  def add_format_check(table, column)
    add_check_constraint(
      table,
      "#{column} IS NULL OR #{column} ~ '#{FORMAT_REGEX}'",
      name: constraint_name(table, column),
    )
  end

  def constraint_name(table, column)
    base = "chk_#{table}_#{column}_format"
    return base if base.length <= 63

    digest = Digest::SHA256.hexdigest(base)[0, 10]
    "chk_#{table}_#{column}_#{digest}"
  end
end
