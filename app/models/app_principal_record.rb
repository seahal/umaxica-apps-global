# typed: false
# frozen_string_literal: true

# Semantic principal/actor base backed by the consolidated app zenith database.
class AppPrincipalRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :app_zenith, reading: :app_zenith_replica }
end
