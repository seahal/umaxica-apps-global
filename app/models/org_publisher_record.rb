# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Staff CMS post and publication data for the org surface.
class OrgPublisherRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :org_publisher, reading: :org_publisher_replica }
end
