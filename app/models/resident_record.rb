# typed: false
# frozen_string_literal: true

# Deployment scope: Local
# Region-specific. Each region (jp, us, etc.) has its own isolated database instance.
class ResidentRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :resident, reading: :resident_replica }
end
