# frozen_string_literal: true

module Publishing
  module Help
    module Com
      class Entry < PublishingRecord
        self.table_name = "publishing_help_com_entries"
        include PublishingEntryRecord

        SURFACE = 'help'
        AUDIENCE = 'com'
        REGION_CODE = "jp"

      end
    end
  end
end
