# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
class OrgRpRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :org_zenith, reading: :org_zenith_replica }
end
