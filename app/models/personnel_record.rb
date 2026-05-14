# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
class PersonnelRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :personnel, reading: :personnel_replica }
end
