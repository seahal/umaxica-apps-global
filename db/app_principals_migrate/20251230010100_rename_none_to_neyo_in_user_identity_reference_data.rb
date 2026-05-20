# frozen_string_literal: true

class RenameNoneToNeyoInUserIdentityReferenceData < ActiveRecord::Migration[8.2]
  def up
    rename_id_tables(
      %w(
        user_identity_statuses
        user_identity_email_statuses
        user_identity_telephone_statuses
        user_identity_one_time_password_statuses
        user_identity_audit_events
        user_identity_audit_levels
      ), from: "NONE", to: "NEYO",
    )

    update_fk(:users, :user_identity_status_id, from: "NONE", to: "NEYO")
    update_fk(:user_identity_emails, :user_identity_email_status_id, from: "NONE", to: "NEYO")
    update_fk(:user_identity_telephones, :user_identity_telephone_status_id, from: "NONE", to: "NEYO")
    update_fk(:user_identity_one_time_passwords, :user_identity_one_time_password_status_id, from: "NONE", to: "NEYO")
    update_fk(:user_identity_audits, :event_id, from: "NONE", to: "NEYO")
    update_fk(:user_identity_audits, :level_id, from: "NONE", to: "NEYO")

    change_column_default_if_exists(:users, :user_identity_status_id, from: "NONE", to: "NEYO")
    change_column_default_if_exists(:user_identity_emails, :user_identity_email_status_id, from: "NONE", to: "NEYO")
    change_column_default_if_exists(
      :user_identity_telephones, :user_identity_telephone_status_id, from: "NONE",
                                                                     to: "NEYO",
    )
    change_column_default_if_exists(
      :user_identity_one_time_passwords, :user_identity_one_time_password_status_id,
      from: "NONE", to: "NEYO",
    )
    change_column_default_if_exists(:user_identity_audits, :event_id, from: "NONE", to: "NEYO")
    change_column_default_if_exists(:user_identity_audits, :level_id, from: "NONE", to: "NEYO")

    delete_id_tables(
      %w(
        user_identity_statuses
        user_identity_email_statuses
        user_identity_telephone_statuses
        user_identity_one_time_password_statuses
        user_identity_audit_events
        user_identity_audit_levels
      ), id: "NONE",
    )
  end

  def down
    rename_id_tables(
      %w(
        user_identity_statuses
        user_identity_email_statuses
        user_identity_telephone_statuses
        user_identity_one_time_password_statuses
        user_identity_audit_events
        user_identity_audit_levels
      ), from: "NEYO", to: "NONE",
    )

    update_fk(:users, :user_identity_status_id, from: "NEYO", to: "NONE")
    update_fk(:user_identity_emails, :user_identity_email_status_id, from: "NEYO", to: "NONE")
    update_fk(:user_identity_telephones, :user_identity_telephone_status_id, from: "NEYO", to: "NONE")
    update_fk(:user_identity_one_time_passwords, :user_identity_one_time_password_status_id, from: "NEYO", to: "NONE")
    update_fk(:user_identity_audits, :event_id, from: "NEYO", to: "NONE")
    update_fk(:user_identity_audits, :level_id, from: "NEYO", to: "NONE")

    change_column_default_if_exists(:users, :user_identity_status_id, from: "NEYO", to: "NONE")
    change_column_default_if_exists(:user_identity_emails, :user_identity_email_status_id, from: "NEYO", to: "NONE")
    change_column_default_if_exists(
      :user_identity_telephones, :user_identity_telephone_status_id, from: "NEYO",
                                                                     to: "NONE",
    )
    change_column_default_if_exists(
      :user_identity_one_time_passwords, :user_identity_one_time_password_status_id,
      from: "NEYO", to: "NONE",
    )
    change_column_default_if_exists(:user_identity_audits, :event_id, from: "NEYO", to: "NONE")
    change_column_default_if_exists(:user_identity_audits, :level_id, from: "NEYO", to: "NONE")

    delete_id_tables(
      %w(
        user_identity_statuses
        user_identity_email_statuses
        user_identity_telephone_statuses
        user_identity_one_time_password_statuses
        user_identity_audit_events
        user_identity_audit_levels
      ), id: "NEYO",
    )
  end

  private

  def rename_id_tables(tables, from:, to:)
    tables.each do |table|
      rename_id(table, from: from, to: to)
    end
  end

  def rename_id(table, from:, to:)
    return unless table_exists?(table)

    safety_assured do
      # No-op: intentionally left blank.
    end

    change_column_default_if_exists(table, :id, from: from, to: to)
  end

  def insert_sql(_table, _id, _has_timestamps)
    # No-op: data seeding moved to fixtures.
    ""
  end

  def update_fk(table, column, from:, to:)
    return unless table_exists?(table) && column_exists?(table, column)
    return unless string_column?(table, column)

    safety_assured do
      execute(<<~SQL.squish)
        UPDATE #{table}
        SET #{column} = '#{to}'
        WHERE #{column} = '#{from}'
      SQL
    end
  end

  def change_column_default_if_exists(table, column, from:, to:)
    return unless table_exists?(table) && column_exists?(table, column)
    return unless string_column?(table, column)

    change_column_default(table, column, from: from, to: to)
  end

  def delete_id_tables(tables, id:)
    tables.each do |table|
      delete_id(table, id)
    end
  end

  def delete_id(table, _id)
    return unless table_exists?(table)

    safety_assured do
      # No-op: intentionally left blank.
    end
  end

  def string_column?(table, column)
    col = connection.columns(table).find { |c| c.name == column.to_s }
    col && %i(string text).include?(col.type)
  end
end
