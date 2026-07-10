# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
class OrgSignalRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :org_signal, reading: :org_signal_replica }
end
