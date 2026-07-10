# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
class OrgTicketRecord < ApplicationRecord
  self.abstract_class = true
  include TokenJsonSanitizable

  connects_to database: { writing: :org_ticket, reading: :org_ticket_replica }
end
