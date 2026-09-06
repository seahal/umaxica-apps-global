# frozen_string_literal: true

module Publishing
  module Help
    module App
      class Entry < PublishingRecord
        self.table_name = "publishing_help_app_entries"
        include PublishingEntryRecord

        SURFACE = 'help'
        AUDIENCE = 'app'
        REGION_CODE = "jp"

      end
    end
  end
end
