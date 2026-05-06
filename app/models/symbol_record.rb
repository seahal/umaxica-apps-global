# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
class SymbolRecord < ApplicationRecord
  self.abstract_class = true
  # FIXME: Is this needed?
  include TokenJsonSanitizable

  connects_to database: { writing: :symbol, reading: :symbol_replica }
end
