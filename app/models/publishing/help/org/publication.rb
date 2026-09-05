# frozen_string_literal: true

module Publishing
  module Help
    module Org
      class Publication < PublishingRecord
        self.table_name = "publishing_help_org_publications"
        include Publishing::PublicationRecord

      end
    end
  end
end
