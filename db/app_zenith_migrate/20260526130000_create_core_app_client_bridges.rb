# frozen_string_literal: true

class CreateCoreAppClientBridges < ActiveRecord::Migration[8.2]
  def change
    create_table(:core_app_client_bridges, id: :bigserial) do |t|
      t.references(:client, null: false)
      t.string(:public_id, null: false, default: "")
      t.string(:rp_client_id, null: false, default: "core_app")
      t.string(:audience, null: false, default: "umaxica-core-app")
      t.string(:host, null: false, default: "www-jp.umaxica.app")
      t.integer(:lock_version, null: false, default: 0)
      t.timestamps

      t.index(:public_id, unique: true)
      t.index(%i(client_id rp_client_id), unique: true, name: "idx_core_app_client_bridges_unique_client_rp")
    end
  end
end
