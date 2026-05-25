# typed: false
# frozen_string_literal: true

# Deployment scope: Local
# Public corporate post and publication data for the com surface.
class ComPublisherRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :com_publisher, reading: :com_publisher_replica }
end
