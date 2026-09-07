# frozen_string_literal: true

module Publishing
  module Info
    module Com
      class EntryVersion < PublishingRecord
        self.table_name = "publishing_info_com_entry_versions"
        include PublishingEntryVersionRecord
      end
    end
  end
end
