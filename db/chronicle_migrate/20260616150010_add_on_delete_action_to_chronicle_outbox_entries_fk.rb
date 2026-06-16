# frozen_string_literal: true

class AddOnDeleteActionToChronicleOutboxEntriesFk < ActiveRecord::Migration[8.2]
  def up
    remove_foreign_key(:chronicle_outbox_entries, column: :chronicle_id) if foreign_key_exists?(:chronicle_outbox_entries, column: :chronicle_id)
    add_foreign_key :chronicle_outbox_entries, :chronicles, column: :chronicle_id, on_delete: :nullify, validate: false
  end

  def down
    remove_foreign_key(:chronicle_outbox_entries, column: :chronicle_id) if foreign_key_exists?(:chronicle_outbox_entries, column: :chronicle_id)
    add_foreign_key :chronicle_outbox_entries, :chronicles, column: :chronicle_id, validate: false
  end
end
