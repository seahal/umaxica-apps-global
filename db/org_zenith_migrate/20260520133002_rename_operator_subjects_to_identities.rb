# frozen_string_literal: true

class RenameOperatorSubjectsToIdentities < ActiveRecord::Migration[8.2]
  def up
    rename_table_strict :operator_subject_statuses, :operator_identity_states
    rename_table_strict :operator_subjects, :operator_identities
  end

  def down
    rename_table_strict :operator_identities, :operator_subjects
    rename_table_strict :operator_identity_states, :operator_subject_statuses
  end
end
