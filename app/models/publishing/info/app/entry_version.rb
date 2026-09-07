# frozen_string_literal: true

module Publishing
  module Info
    module App
      class EntryVersion < PublishingRecord
        self.table_name = "publishing_info_app_entry_versions"
        include PublishingEntryVersionRecord
      end
    end
  end
end
