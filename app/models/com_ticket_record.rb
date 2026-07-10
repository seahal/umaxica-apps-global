# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
class ComTicketRecord < ApplicationRecord
  self.abstract_class = true
  # Keep token-like ticket serialization aligned with AppTicketRecord and OrgTicketRecord.
  include TokenJsonSanitizable

  connects_to database: { writing: :com_ticket, reading: :com_ticket_replica }
end
