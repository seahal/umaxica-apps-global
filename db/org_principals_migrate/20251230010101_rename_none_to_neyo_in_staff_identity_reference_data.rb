# frozen_string_literal: true

class RenameNoneToNeyoInStaffIdentityReferenceData < ActiveRecord::Migration[8.2]
  def up
    rename_id_tables(
      %w(
        staff_identity_statuses
        staff_identity_audit_events
        staff_identity_audit_levels
      ), from: "NONE", to: "NEYO",
    )

    update_fk(:staffs, :staff_identity_status_id, from: "NONE", to: "NEYO")
    update_fk(:staff_identity_audits, :event_id, from: "NONE", to: "NEYO")
    update_fk(:staff_identity_audits, :level_id, from: "NONE", to: "NEYO")

    change_column_default_if_exists(:staffs, :staff_identity_status_id, from: "NONE", to: "NEYO")
    change_column_default_if_exists(:staff_identity_audits, :event_id, from: "NONE", to: "NEYO")
    change_column_default_if_exists(:staff_identity_audits, :level_id, from: "NONE", to: "NEYO")

    delete_id_tables(
      %w(
        staff_identity_statuses
        staff_identity_audit_events
        staff_identity_audit_levels
      ), id: "NONE",
    )
  end

  def down
    rename_id_tables(
      %w(
        staff_identity_statuses
        staff_identity_audit_events
        staff_identity_audit_levels
      ), from: "NEYO", to: "NONE",
    )

    update_fk(:staffs, :staff_identity_status_id, from: "NEYO", to: "NONE")
    update_fk(:staff_identity_audits, :event_id, from: "NEYO", to: "NONE")
    update_fk(:staff_identity_audits, :level_id, from: "NEYO", to: "NONE")

    change_column_default_if_exists(:staffs, :staff_identity_status_id, from: "NEYO", to: "NONE")
    change_column_default_if_exists(:staff_identity_audits, :event_id, from: "NEYO", to: "NONE")
    change_column_default_if_exists(:staff_identity_audits, :level_id, from: "NEYO", to: "NONE")

    delete_id_tables(
      %w(
        staff_identity_statuses
        staff_identity_audit_events
        staff_identity_audit_levels
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

  def update_fk(table, column, from:, to:)
    return unless table_exists?(table) && column_exists?(table, column)

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
end
