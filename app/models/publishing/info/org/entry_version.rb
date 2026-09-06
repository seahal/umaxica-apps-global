# frozen_string_literal: true

module Publishing
  module Info
    module Org
      class EntryVersion < PublishingRecord
        self.table_name = "publishing_info_org_entry_versions"
        include PublishingEntryVersionRecord
      end
    end
  end
end
