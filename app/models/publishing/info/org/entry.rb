# frozen_string_literal: true

module Publishing
  module Info
    module Org
      class Entry < PublishingRecord
        self.table_name = "publishing_info_org_entries"
        include PublishingEntryRecord

        SURFACE = 'info'
        AUDIENCE = 'org'
        REGION_CODE = nil

      end
    end
  end
end
