# frozen_string_literal: true

require "digest"

class AddFormatChecksToUserIdentityFkIds < ActiveRecord::Migration[8.2]
  FORMAT_REGEX = "^[A-Z0-9_]+$"

  def change
    add_format_check(:user_identity_audits, :event_id)
    add_format_check(:user_identity_audits, :level_id)

    add_format_check(:user_identity_emails, :user_identity_email_status_id)
    add_format_check(:user_identity_one_time_passwords, :user_identity_one_time_password_status_id)
    add_format_check(:user_identity_passkeys, :user_identity_passkey_status_id)
    add_format_check(:user_identity_secrets, :user_identity_secret_status_id)
    add_format_check(:user_identity_social_apples, :user_identity_social_apple_status_id)
    add_format_check(:user_identity_social_googles, :user_identity_social_google_status_id)
    add_format_check(:user_identity_telephones, :user_identity_telephone_status_id)
    add_format_check(:users, :user_identity_status_id)
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
