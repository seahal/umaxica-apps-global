# frozen_string_literal: true

module Publishing
  module Info
    module Org
      class Publication < PublishingRecord
        self.table_name = "publishing_info_org_publications"
        include PublishingPublicationRecord

      end
    end
  end
end
