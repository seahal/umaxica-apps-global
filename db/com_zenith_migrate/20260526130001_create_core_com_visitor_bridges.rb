# frozen_string_literal: true

class CreateCoreComVisitorBridges < ActiveRecord::Migration[8.2]
  def change
    create_table(:core_com_visitor_bridges, id: :bigserial) do |t|
      t.references(:visitor, null: false)
      t.string(:public_id, null: false, default: "")
      t.string(:rp_client_id, null: false, default: "core_com")
      t.string(:audience, null: false, default: "umaxica-core-com")
      t.string(:host, null: false, default: "www.jp.umaxica.com")
      t.integer(:lock_version, null: false, default: 0)
      t.timestamps

      t.index(:public_id, unique: true)
      t.index(%i(visitor_id rp_client_id), unique: true, name: "idx_core_com_visitor_bridges_unique_visitor_rp")
    end
  end
end
