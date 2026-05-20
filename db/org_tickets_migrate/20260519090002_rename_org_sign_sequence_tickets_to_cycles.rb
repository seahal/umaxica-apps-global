class RenameOrgSignSequenceTicketsToCycles < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      rename_table_if_present :org_sign_in_sequence_tickets, :org_sign_in_cycles
      rename_table_if_present :org_sign_up_sequence_tickets, :org_sign_up_cycles
    end
  end

  def down
    safety_assured do
      rename_table_if_present :org_sign_in_cycles, :org_sign_in_sequence_tickets
      rename_table_if_present :org_sign_up_cycles, :org_sign_up_sequence_tickets
    end
  end

  private

  def rename_table_if_present(from, to)
    return unless table_exists?(from)
    return if table_exists?(to)

    rename_table from, to
  end
end
