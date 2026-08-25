# frozen_string_literal: true

# The org surface federates a single Entra tenant configured in Rails
# credentials, so an identity is no longer scoped to an
# OrganizationEntraConnection row. The lookup key is unchanged: the
# (entra_tenant_id, entra_object_id) unique index.
#
# connection_id becomes nullable and loses its foreign key rather than being
# dropped, and organization_entra_connections is left in place: multi-tenant
# federation is a plausible future requirement, and neither the column nor the
# table carries data that sign-in now reads.
class DetachOperatorEntraIdentitiesFromConnections < ActiveRecord::Migration[8.2]
  def up
    remove_foreign_key(:operator_entra_identities, :organization_entra_connections, column: :connection_id)
    change_column_null(:operator_entra_identities, :connection_id, true)
  end

  def down
    change_column_null(:operator_entra_identities, :connection_id, false)
    add_foreign_key(:operator_entra_identities, :organization_entra_connections,
                    column: :connection_id, validate: false)
  end
end
