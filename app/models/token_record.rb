# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
class TokenRecord < ApplicationRecord
  self.abstract_class = true
  include TokenJsonSanitizable

  connects_to database: { writing: :token, reading: :token_replica }
end
