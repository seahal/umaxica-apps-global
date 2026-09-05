# frozen_string_literal: true

module Publishing
  module Info
    module Com
      class Entry < PublishingRecord
        self.table_name = "publishing_info_com_entries"
        include Publishing::EntryRecord

        SURFACE = 'info'
        AUDIENCE = 'com'
        REGION_CODE = nil

      end
    end
  end
end
