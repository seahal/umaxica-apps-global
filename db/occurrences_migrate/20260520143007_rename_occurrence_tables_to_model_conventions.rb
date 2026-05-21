# frozen_string_literal: true

class RenameOccurrenceTablesToModelConventions < ActiveRecord::Migration[8.2]
  def up
    rename_table_strict :area_staff_occurrences, :area_operator_occurrences
    rename_table_strict :area_user_occurrences, :area_client_occurrences
    rename_table_strict :domain_staff_occurrences, :domain_operator_occurrences
    rename_table_strict :domain_user_occurrences, :domain_client_occurrences
    rename_table_strict :email_staff_occurrences, :email_operator_occurrences
    rename_table_strict :email_user_occurrences, :email_client_occurrences
    rename_table_strict :ip_staff_occurrences, :ip_operator_occurrences
    rename_table_strict :ip_user_occurrences, :ip_client_occurrences
    rename_table_strict :staff_occurrence_statuses, :operator_occurrence_statuses
    rename_table_strict :staff_occurrences, :operator_occurrences
    rename_table_strict :staff_telephone_occurrences, :operator_telephone_occurrences
    rename_table_strict :staff_user_occurrences, :operator_client_occurrences
    rename_table_strict :staff_zip_occurrences, :operator_zip_occurrences
    rename_table_strict :telephone_user_occurrences, :telephone_client_occurrences
    rename_table_strict :user_occurrence_statuses, :client_occurrence_statuses
    rename_table_strict :user_occurrences, :client_occurrences
    rename_table_strict :user_zip_occurrences, :client_zip_occurrences
  end

  def down
    rename_table_strict :client_zip_occurrences, :user_zip_occurrences
    rename_table_strict :client_occurrences, :user_occurrences
    rename_table_strict :client_occurrence_statuses, :user_occurrence_statuses
    rename_table_strict :telephone_client_occurrences, :telephone_user_occurrences
    rename_table_strict :operator_zip_occurrences, :staff_zip_occurrences
    rename_table_strict :operator_client_occurrences, :staff_user_occurrences
    rename_table_strict :operator_telephone_occurrences, :staff_telephone_occurrences
    rename_table_strict :operator_occurrences, :staff_occurrences
    rename_table_strict :operator_occurrence_statuses, :staff_occurrence_statuses
    rename_table_strict :ip_client_occurrences, :ip_user_occurrences
    rename_table_strict :ip_operator_occurrences, :ip_staff_occurrences
    rename_table_strict :email_client_occurrences, :email_user_occurrences
    rename_table_strict :email_operator_occurrences, :email_staff_occurrences
    rename_table_strict :domain_client_occurrences, :domain_user_occurrences
    rename_table_strict :domain_operator_occurrences, :domain_staff_occurrences
    rename_table_strict :area_client_occurrences, :area_user_occurrences
    rename_table_strict :area_operator_occurrences, :area_staff_occurrences
  end
end
