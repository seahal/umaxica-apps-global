# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
class ComSignalRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :com_signal, reading: :com_signal_replica }
end
