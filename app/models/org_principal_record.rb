# typed: false
# frozen_string_literal: true

# Semantic principal/actor base backed by the consolidated org zenith database.
class OrgPrincipalRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :org_zenith, reading: :org_zenith_replica }
end
