# typed: false
# frozen_string_literal: true

# Deployment scope: Local
# Region-specific. Each region (jp, us, etc.) has its own isolated database instance.
class ComPrincipalRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :com_principal, reading: :com_principal_replica }
end
