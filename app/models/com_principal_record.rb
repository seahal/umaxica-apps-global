# typed: false
# frozen_string_literal: true

# Semantic principal/actor base backed by the consolidated com zenith database.
class ComPrincipalRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :com_zenith, reading: :com_zenith_replica }
end
