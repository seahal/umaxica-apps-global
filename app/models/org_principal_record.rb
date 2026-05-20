# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
class OrgPrincipalRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :org_principal, reading: :org_principal_replica }
end
