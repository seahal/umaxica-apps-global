# frozen_string_literal: true

class CreateCoreOrgOperatorBridges < ActiveRecord::Migration[8.2]
  def change
    create_table(:core_org_operator_bridges, id: :bigserial) do |t|
      t.references(:operator, null: false)
      t.string(:public_id, null: false, default: "")
      t.string(:rp_client_id, null: false, default: "core_org")
      t.string(:audience, null: false, default: "umaxica-core-org")
      t.string(:host, null: false, default: "www-jp.umaxica.org")
      t.integer(:lock_version, null: false, default: 0)
      t.timestamps

      t.index(:public_id, unique: true)
      t.index(%i(operator_id rp_client_id), unique: true, name: "idx_core_org_operator_bridges_unique_operator_rp")
    end
  end
end
