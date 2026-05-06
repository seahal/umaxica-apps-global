# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
class MarkRecord < ApplicationRecord
  include TokenJsonSanitizable

  self.abstract_class = true

  connects_to database: { writing: :mark, reading: :mark_replica }
end
