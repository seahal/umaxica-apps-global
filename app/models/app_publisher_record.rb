# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# End-user post and publication data for the app surface.
class AppPublisherRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :app_publisher, reading: :app_publisher_replica }
end
