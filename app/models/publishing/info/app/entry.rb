# frozen_string_literal: true

module Publishing
  module Info
    module App
      class Entry < PublishingRecord
        self.table_name = "publishing_info_app_entries"
        include PublishingEntryRecord

        SURFACE = "info"
        AUDIENCE = "app"
        REGION_CODE = nil
      end
    end
  end
end
