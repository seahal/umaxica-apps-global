# frozen_string_literal: true

class RenameClientSubjectsToIdentities < ActiveRecord::Migration[8.2]
  def up
    rename_table_strict :client_subject_statuses, :client_identity_states
    rename_table_strict :client_subjects, :client_identities
  end

  def down
    rename_table_strict :client_identities, :client_subjects
    rename_table_strict :client_identity_states, :client_subject_statuses
  end
end
