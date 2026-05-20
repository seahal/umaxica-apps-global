# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
class AppPrincipalRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :app_principal, reading: :app_principal_replica }
end
