# typed: false
# frozen_string_literal: true

# Deployment scope: Local
# Region-specific. Each region (jp, us, etc.) has its own isolated database instance.
class VisitorRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :visitor, reading: :visitor_replica }
end
