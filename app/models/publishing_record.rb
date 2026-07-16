# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Central content authority for info/docs/news/help across all audiences.
class PublishingRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :publishing, reading: :publishing_replica }
end
