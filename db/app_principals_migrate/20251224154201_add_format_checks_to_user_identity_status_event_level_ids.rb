# frozen_string_literal: true

require "digest"

class AddFormatChecksToUserIdentityStatusEventLevelIds < ActiveRecord::Migration[8.2]
  FORMAT_REGEX = "^[A-Z0-9_]+$"

  def change
    add_format_check(:user_identity_statuses, :id)

    add_format_check(:user_identity_email_statuses, :id)
    add_format_check(:user_identity_telephone_statuses, :id)

    add_format_check(:user_identity_secret_statuses, :id)

    add_format_check(:user_identity_audit_events, :id)

    add_format_check(:user_identity_audit_levels, :id)

    add_format_check(:user_identity_one_time_password_statuses, :id)
    add_format_check(:user_identity_passkey_statuses, :id)
    add_format_check(:user_identity_social_apple_statuses, :id)
    add_format_check(:user_identity_social_google_statuses, :id)
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
