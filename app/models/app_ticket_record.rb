# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
class AppTicketRecord < ApplicationRecord
  include TokenJsonSanitizable

  self.abstract_class = true

  connects_to database: { writing: :app_ticket, reading: :app_ticket_replica }
end
