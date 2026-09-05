# frozen_string_literal: true

module Publishing
  module Help
    module Org
      class Entry < PublishingRecord
        self.table_name = "publishing_help_org_entries"
        include Publishing::EntryRecord

        SURFACE = 'help'
        AUDIENCE = 'org'
        REGION_CODE = "jp"

      end
    end
  end
end
