# typed: false
# frozen_string_literal: true

# Deployment scope: Local
# Region-specific. Each region (jp, us, etc.) has its own isolated database instance.
class ComRpRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :com_zenith, reading: :com_zenith_replica }
end
