# frozen_string_literal: true

class RenameVisitorSubjectsToIdentities < ActiveRecord::Migration[8.2]
  def up
    rename_table_strict :visitor_subject_statuses, :visitor_identity_states
    rename_table_strict :visitor_subjects, :visitor_identities
  end

  def down
    rename_table_strict :visitor_identities, :visitor_subjects
    rename_table_strict :visitor_identity_states, :visitor_subject_statuses
  end
end
