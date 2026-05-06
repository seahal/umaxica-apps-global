# typed: false
# frozen_string_literal: true

class RedirectorRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :redirector, reading: :redirector_replica }
end
